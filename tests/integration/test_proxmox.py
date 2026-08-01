"""Tests d'intégration Proxmox + nœuds : VM conformes aux outputs Terraform,
guest agent joignable, SSH/DNS/NTP opérationnels, /dev/kvm sur les computes.
Lecture seule (API + SSH)."""

from __future__ import annotations

import os
import subprocess

import pytest
import requests

pytestmark = pytest.mark.skipif(
    not os.environ.get("PROXMOX_API_URL") or not os.environ.get("PROXMOX_TOKEN_ID"),
    reason="PROXMOX_API_URL/PROXMOX_TOKEN_ID absents : test exécutable uniquement en pipeline.",
)

SSH_OPTIONS = [
    "-o",
    "BatchMode=yes",
    "-o",
    "StrictHostKeyChecking=accept-new",
    "-o",
    "ConnectTimeout=10",
]


@pytest.fixture(scope="module")
def proxmox() -> requests.Session:
    session = requests.Session()
    session.headers["Authorization"] = (
        f"PVEAPIToken={os.environ['PROXMOX_TOKEN_ID']}={os.environ['PROXMOX_TOKEN_SECRET']}"
    )
    session.verify = os.environ.get("PROXMOX_INSECURE", "false") != "true"
    return session


def proxmox_get(session: requests.Session, path: str) -> dict:
    base = os.environ["PROXMOX_API_URL"].rstrip("/")
    response = session.get(f"{base}/{path}", timeout=30)
    response.raise_for_status()
    return response.json()["data"]


def ssh(target: str, command: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["ssh", *SSH_OPTIONS, target, command],
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )


def test_vms_exist_with_expected_resources(proxmox: requests.Session, live_outputs: dict) -> None:
    cluster_vms = {vm["name"]: vm for vm in proxmox_get(proxmox, "cluster/resources?type=vm")}
    for name, resource in live_outputs["proxmox_resources"].items():
        assert name in cluster_vms, f"VM Proxmox '{name}' absente du cluster."
        vm = cluster_vms[name]
        assert vm["vmid"] == resource["vm_id"]
        assert vm["node"] == resource["node_name"]
        assert vm["status"] == "running", f"VM '{name}' non démarrée ({vm['status']})."


def test_vm_tags(proxmox: requests.Session, live_outputs: dict) -> None:
    env_id = live_outputs["environment_manifest"]["environment_id"]
    for name, resource in live_outputs["proxmox_resources"].items():
        config = proxmox_get(proxmox, f"nodes/{resource['node_name']}/qemu/{resource['vm_id']}/config")
        tags = set((config.get("tags") or "").split(";"))
        assert {"eph", "openstack", "managed_by_terraform", f"environment_{env_id}"} <= tags, (
            f"Tags manquants sur '{name}': {tags}"
        )


def test_guest_agent_responds(proxmox: requests.Session, live_outputs: dict) -> None:
    for name, resource in live_outputs["proxmox_resources"].items():
        base = os.environ["PROXMOX_API_URL"].rstrip("/")
        response = proxmox.get(
            f"{base}/nodes/{resource['node_name']}/qemu/{resource['vm_id']}/agent/ping",
            timeout=30,
        )
        assert response.status_code == 200, f"QEMU guest agent injoignable sur '{name}'."


def test_interfaces_match_terraform(proxmox: requests.Session, live_outputs: dict) -> None:
    for name, resource in live_outputs["proxmox_resources"].items():
        config = proxmox_get(proxmox, f"nodes/{resource['node_name']}/qemu/{resource['vm_id']}/config")
        node = live_outputs["nodes"][name]
        for nic in node["interfaces"].values():
            expected_mac = nic["mac_address"].upper()
            matches = [
                value
                for key, value in config.items()
                if key.startswith("net") and expected_mac in str(value).upper()
            ]
            assert matches, f"{name}: NIC {expected_mac} ({nic['linux_name']}) absente de la config Proxmox."
            assert f"bridge={nic['bridge']}" in matches[0], f"{name}/{nic['linux_name']}: mauvais bridge."


def test_ssh_and_ip_configuration(live_outputs: dict) -> None:
    for target in live_outputs["ssh_targets"]:
        result = ssh(target, "hostname && ip -o -4 addr show")
        assert result.returncode == 0, f"SSH KO vers {target}: {result.stderr}"
        expected_ip = target.split("@", 1)[1]
        assert expected_ip in result.stdout, f"{target}: IP management absente de la configuration."


def test_time_sync_and_dns(live_outputs: dict) -> None:
    for target in live_outputs["ssh_targets"]:
        sync = ssh(target, "timedatectl show -p NTPSynchronized --value")
        assert sync.returncode == 0
        assert sync.stdout.strip() == "yes", f"{target}: horloge non synchronisée NTP."
        dns = ssh(target, "getent hosts localhost")
        assert dns.returncode == 0, f"{target}: résolution de noms défaillante."


def test_dev_kvm_on_computes(live_outputs: dict) -> None:
    computes = [name for name, node in live_outputs["nodes"].items() if node["role"] in ("compute", "aio")]
    assert computes, "Aucun nœud compute dans la topologie."
    for name in computes:
        target = (
            f"{live_outputs['ssh_targets'][0].split('@')[0]}@{live_outputs['nodes'][name]['management_ip']}"
        )
        result = ssh(target, "test -e /dev/kvm && grep -Ec '(vmx|svm)' /proc/cpuinfo")
        assert result.returncode == 0 and int(result.stdout.strip() or 0) > 0, (
            f"{name}: /dev/kvm ou extensions vmx/svm absents — virtualisation "
            "imbriquée non fonctionnelle (voir docs/PROXMOX.md)."
        )
