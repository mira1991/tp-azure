"""Tests unitaires de scripts/generate-import-blocks.py."""

from __future__ import annotations

import json
from pathlib import Path

from tests.unit.test_validate_inputs import load_script

generate = load_script("generate-import-blocks.py")


def make_report(tmp_path: Path) -> Path:
    report = {
        "mode": "environment",
        "environment_id": 142,
        "state_compared": True,
        "resources": [
            {
                "kind": "netbox_virtual_machine",
                "id": "101",
                "name": "eph-osk-upg-142-aio-01",
                "display": "eph-osk-upg-142-aio-01",
                "address": "",
                "node": "",
                "in_state": False,
            },
            {
                "kind": "proxmox_vm",
                "id": "4201",
                "name": "eph-osk-upg-142-aio-01",
                "display": "eph-osk-upg-142-aio-01",
                "address": "",
                "node": "pve-02",
                "in_state": False,
            },
        ],
        "orphans": [
            {
                "kind": "netbox_virtual_machine",
                "id": "101",
                "name": "eph-osk-upg-142-aio-01",
                "display": "eph-osk-upg-142-aio-01",
                "address": "",
                "node": "",
                "in_state": False,
            }
        ],
    }
    path = tmp_path / "report.json"
    path.write_text(json.dumps(report), encoding="utf-8")
    return path


def test_import_blocks_generated(tmp_path: Path) -> None:
    report = make_report(tmp_path)
    out = tmp_path / "imports.tf"
    rc = generate.main(["--report", str(report), "--out", str(out)])
    assert rc == 0

    content = out.read_text(encoding="utf-8")
    assert 'netbox_virtual_machine.nodes["eph-osk-upg-142-aio-01"]' in content
    assert 'proxmox_virtual_environment_vm.nodes["eph-osk-upg-142-aio-01"]' in content
    assert 'id = "pve-02/4201"' in content


def test_orphans_only_filters(tmp_path: Path) -> None:
    report = make_report(tmp_path)
    out = tmp_path / "imports.tf"
    rc = generate.main(["--report", str(report), "--out", str(out), "--orphans-only"])
    assert rc == 0

    content = out.read_text(encoding="utf-8")
    assert "netbox_virtual_machine.nodes" in content
    assert "proxmox_virtual_environment_vm" not in content
