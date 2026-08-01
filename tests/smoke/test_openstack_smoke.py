"""Smoke tests OpenStack : santé des services puis cycle de vie complet
réseau -> instance -> volume, via la CLI (opérations de test impératives).
Les ressources créées ici sont supprimées en fin de test."""

from __future__ import annotations

import json
import os
import subprocess
import time
import uuid

import pytest

pytestmark = pytest.mark.skipif(
    not os.environ.get("OS_CLOUD"),
    reason="OS_CLOUD absent : smoke tests exécutables uniquement en pipeline.",
)

RUN_CINDER = os.environ.get("RUN_CINDER_TESTS", "true") == "true"
RUN_OCTAVIA = os.environ.get("RUN_OCTAVIA_TESTS", "false") == "true"
RUN_DESIGNATE = os.environ.get("RUN_DESIGNATE_TESTS", "false") == "true"

SMOKE_ID = uuid.uuid4().hex[:8]


def openstack(*args: str, timeout: int = 300) -> list | dict:
    result = subprocess.run(
        ["openstack", *args, "-f", "json"],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(f"openstack {' '.join(args)} a échoué : {result.stderr.strip()}")
    return json.loads(result.stdout or "null")


def openstack_raw(*args: str, timeout: int = 300) -> None:
    result = subprocess.run(
        ["openstack", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(f"openstack {' '.join(args)} a échoué : {result.stderr.strip()}")


def wait_for(predicate, timeout: int = 600, interval: int = 10, label: str = "condition") -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(interval)
    raise AssertionError(f"Timeout en attendant : {label}")


# ---------------------------------------------------------------------------
# Santé des services
# ---------------------------------------------------------------------------


def test_service_and_endpoint_lists() -> None:
    services = {service["Name"] for service in openstack("service", "list")}
    assert {"keystone", "glance", "nova", "neutron", "placement"} <= services
    assert openstack("endpoint", "list"), "Aucun endpoint Keystone."


def test_compute_services_up() -> None:
    rows = openstack("compute", "service", "list")
    assert rows, "Aucun service compute."
    down = [row for row in rows if row["Status"] == "enabled" and row["State"] != "up"]
    assert not down, f"Services compute down : {down}"


def test_hypervisors_present() -> None:
    assert openstack("hypervisor", "list"), "Aucun hyperviseur enregistré."


def test_network_agents_up() -> None:
    rows = openstack("network", "agent", "list")
    assert rows, "Aucun agent réseau."
    down = [row for row in rows if not row["Alive"]]
    assert not down, f"Agents réseau down : {down}"


@pytest.mark.skipif(not RUN_CINDER, reason="RUN_CINDER_TESTS=false")
def test_volume_services_up() -> None:
    rows = openstack("volume", "service", "list")
    down = [row for row in rows if row["Status"] == "enabled" and row["State"] != "up"]
    assert not down, f"Services volume down : {down}"


def test_image_and_network_lists() -> None:
    assert openstack("image", "list"), "Aucune image Glance (openstack-config non appliqué ?)."
    assert openstack("network", "list"), "Aucun réseau Neutron."


@pytest.mark.skipif(not RUN_OCTAVIA, reason="RUN_OCTAVIA_TESTS=false")
def test_octavia_amphorae_reachable() -> None:
    assert isinstance(openstack("loadbalancer", "list"), list)


@pytest.mark.skipif(not RUN_DESIGNATE, reason="RUN_DESIGNATE_TESTS=false")
def test_designate_zones_listable() -> None:
    assert isinstance(openstack("zone", "list"), list)


# ---------------------------------------------------------------------------
# Cycle de vie complet
# ---------------------------------------------------------------------------


def test_full_instance_lifecycle() -> None:
    net = f"eph-smoke-{SMOKE_ID}-net"
    subnet = f"eph-smoke-{SMOKE_ID}-subnet"
    router = f"eph-smoke-{SMOKE_ID}-router"
    secgroup = f"eph-smoke-{SMOKE_ID}-sg"
    server = f"eph-smoke-{SMOKE_ID}-vm"
    volume = f"eph-smoke-{SMOKE_ID}-vol"

    image = os.environ.get("SMOKE_IMAGE", "eph-cirros")
    flavor = os.environ.get("SMOKE_FLAVOR", "eph.tiny")

    try:
        openstack("network", "create", net)
        openstack(
            "subnet",
            "create",
            subnet,
            "--network",
            net,
            "--subnet-range",
            "10.252.0.0/24",
        )
        openstack("router", "create", router)
        openstack_raw("router", "add", "subnet", router, subnet)
        openstack("security", "group", "create", secgroup)
        openstack(
            "security",
            "group",
            "rule",
            "create",
            secgroup,
            "--protocol",
            "icmp",
            "--ingress",
        )

        openstack(
            "server",
            "create",
            server,
            "--image",
            image,
            "--flavor",
            flavor,
            "--network",
            net,
            "--security-group",
            secgroup,
            timeout=600,
        )
        wait_for(
            lambda: openstack("server", "show", server)["status"] == "ACTIVE",
            timeout=600,
            label=f"statut ACTIVE de {server}",
        )

        addresses = openstack("server", "show", server)["addresses"]
        assert addresses, "Instance sans adresse réseau."

        if RUN_CINDER:
            openstack("volume", "create", "--size", "1", volume)
            wait_for(
                lambda: openstack("volume", "show", volume)["status"] == "available",
                timeout=300,
                label=f"volume {volume} disponible",
            )
            openstack_raw("server", "add", "volume", server, volume)
            wait_for(
                lambda: openstack("volume", "show", volume)["status"] == "in-use",
                timeout=300,
                label=f"volume {volume} attaché",
            )
            openstack_raw("server", "remove", "volume", server, volume)
            wait_for(
                lambda: openstack("volume", "show", volume)["status"] == "available",
                timeout=300,
                label=f"volume {volume} détaché",
            )
    finally:
        subprocess.run(["openstack", "server", "delete", "--wait", server], check=False)
        if RUN_CINDER:
            subprocess.run(["openstack", "volume", "delete", volume], check=False)
        subprocess.run(["openstack", "router", "remove", "subnet", router, subnet], check=False)
        subprocess.run(["openstack", "router", "delete", router], check=False)
        subprocess.run(["openstack", "subnet", "delete", subnet], check=False)
        subprocess.run(["openstack", "network", "delete", net], check=False)
        subprocess.run(["openstack", "security", "group", "delete", secgroup], check=False)
