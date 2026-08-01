"""Tests d'intégration NetBox : cohérence entre le state Terraform (outputs)
et l'état réel de NetBox après l'apply substrate. Lecture seule."""

from __future__ import annotations

import os
from typing import Any

import pytest
import requests

pytestmark = pytest.mark.skipif(
    not os.environ.get("NETBOX_URL") or not os.environ.get("NETBOX_TOKEN"),
    reason="NETBOX_URL/NETBOX_TOKEN absents : test exécutable uniquement en pipeline.",
)


@pytest.fixture(scope="module")
def netbox() -> requests.Session:
    session = requests.Session()
    session.headers["Authorization"] = f"Token {os.environ['NETBOX_TOKEN']}"
    session.headers["Accept"] = "application/json"
    return session


def netbox_get(session: requests.Session, path: str, **params: Any) -> dict:
    base = os.environ["NETBOX_URL"].rstrip("/")
    response = session.get(f"{base}/api/{path}/", params=params, timeout=30)
    response.raise_for_status()
    return response.json()


def test_virtual_machines_present(netbox: requests.Session, live_outputs: dict) -> None:
    for name, vm_id in live_outputs["netbox_resources"]["virtual_machines"].items():
        payload = netbox_get(netbox, "virtualization/virtual-machines", name=name)
        assert payload["count"] == 1, f"VM NetBox '{name}' absente ou dupliquée."
        vm = payload["results"][0]
        assert str(vm["id"]) == str(vm_id)
        assert vm["status"]["value"] == "active"


def test_vm_tags_and_custom_fields(netbox: requests.Session, live_outputs: dict) -> None:
    manifest = live_outputs["environment_manifest"]
    expected_tag = f"environment-{manifest['environment_id']}"
    for name in live_outputs["netbox_resources"]["virtual_machines"]:
        vm = netbox_get(netbox, "virtualization/virtual-machines", name=name)["results"][0]
        tags = {tag["name"] for tag in vm["tags"]}
        assert {"eph", "openstack", "managed-by-terraform", expected_tag} <= tags
        fields = vm.get("custom_fields") or {}
        if "managed_by" in fields:
            assert fields["managed_by"] == "terraform-gitlab"
        if "environment_name" in fields:
            assert fields["environment_name"] == manifest["environment_name"]


def test_interfaces_present_with_correct_vlan(netbox: requests.Session, live_outputs: dict) -> None:
    nodes = live_outputs["nodes"]
    for vm_name, node in nodes.items():
        payload = netbox_get(netbox, "virtualization/interfaces", virtual_machine=vm_name)
        by_name = {interface["name"]: interface for interface in payload["results"]}
        for role, nic in node["interfaces"].items():
            assert nic["linux_name"] in by_name, f"{vm_name}: interface {nic['linux_name']} ({role}) absente."
            interface = by_name[nic["linux_name"]]
            untagged = interface.get("untagged_vlan") or {}
            assert untagged.get("vid") == nic["vlan_id"], f"{vm_name}/{role}: VLAN incorrect."


def test_ips_bound_to_interfaces_with_status(netbox: requests.Session, live_outputs: dict) -> None:
    expected_status = os.environ.get("NETBOX_EPHEMERAL_IP_STATUS", "reserved")
    for key, ip_info in live_outputs["netbox_resources"]["ip_addresses"].items():
        vm_name, role = key.split("/", 1)
        payload = netbox_get(netbox, "ipam/ip-addresses", address=ip_info["ip_address"])
        assert payload["count"] == 1, f"IP {ip_info['ip_address']} absente ou dupliquée (collision ?)."
        address = payload["results"][0]
        assert address["status"]["value"] == expected_status
        assigned = address.get("assigned_object") or {}
        assert assigned.get("virtual_machine", {}).get("name") == vm_name, (
            f"IP {ip_info['ip_address']} non associée à la bonne VM ({role})."
        )


def test_no_ip_collision(live_outputs: dict) -> None:
    addresses = [info["ip_address"] for info in live_outputs["netbox_resources"]["ip_addresses"].values()]
    addresses.append(live_outputs["netbox_resources"]["internal_vip"]["ip_address"])
    assert len(addresses) == len(set(addresses)), "Collision d'adresses IP entre allocations."


def test_primary_ip_set(netbox: requests.Session, live_outputs: dict) -> None:
    for name in live_outputs["netbox_resources"]["virtual_machines"]:
        vm = netbox_get(netbox, "virtualization/virtual-machines", name=name)["results"][0]
        primary = vm.get("primary_ip4") or {}
        expected = live_outputs["management_ips"][name]
        assert (primary.get("address") or "").split("/")[0] == expected, (
            f"{name}: primary IP NetBox != IP management Terraform."
        )
