"""Tests unitaires de scripts/render-terraform-outputs.py."""

from __future__ import annotations

import json
import stat
from pathlib import Path

import yaml

from tests.unit.test_validate_inputs import REPO_ROOT, load_script

render = load_script("render-terraform-outputs.py")

FIXTURES = REPO_ROOT / "tests" / "fixtures"


def test_inventory_merges_service_groups(tmp_path: Path, sample_outputs_file: Path) -> None:
    out_dir = tmp_path / "inventory"
    rc = render.main(
        [
            "inventory",
            "--outputs",
            str(sample_outputs_file),
            "--out-dir",
            str(out_dir),
            "--kolla-multinode",
            str(FIXTURES / "kolla-multinode-service-groups.ini"),
        ]
    )
    assert rc == 0

    multinode = (out_dir / "multinode").read_text(encoding="utf-8")
    # Groupes d'hôtes Terraform en tête...
    assert "[deployment]" in multinode
    assert "eph-osk-upg-142-aio-01" in multinode
    # ... suivis des groupes de services du multinode packagé.
    assert "[baremetal:children]" in multinode
    assert multinode.index("[deployment]") < multinode.index("[baremetal:children]")
    # localhost (hôtes d'exemple du multinode packagé) ne doit PAS être repris.
    hosts_section = multinode[: multinode.index("[baremetal:children]")]
    assert "localhost" not in hosts_section

    host_vars = out_dir / "host_vars" / "eph-osk-upg-142-aio-01.yml"
    assert host_vars.exists()
    assert "neutron_external_interface: eth3" in host_vars.read_text(encoding="utf-8")


def test_manifest_written(tmp_path: Path, sample_outputs_file: Path) -> None:
    out = tmp_path / "manifest.json"
    rc = render.main(["manifest", "--outputs", str(sample_outputs_file), "--out", str(out)])
    assert rc == 0

    manifest = json.loads(out.read_text(encoding="utf-8"))
    assert manifest["environment"]["environment_name"] == "eph-osk-upg-142"
    assert manifest["internal_vip_address"] == "192.0.2.20"
    assert "eph-osk-upg-142-aio-01" in manifest["proxmox_resources"]


def test_globals_rendered(tmp_path: Path, sample_outputs_file: Path, monkeypatch) -> None:
    monkeypatch.setenv("KOLLA_REGISTRY", "registry.example:5000")
    monkeypatch.setenv("KOLLA_REGISTRY_NAMESPACE", "openstack.kolla")
    monkeypatch.setenv("RUN_CINDER_TESTS", "true")

    out = tmp_path / "globals.yml"
    rc = render.main(
        [
            "globals",
            "--outputs",
            str(sample_outputs_file),
            "--template",
            str(REPO_ROOT / "kolla" / "globals.yml.j2"),
            "--versions",
            str(REPO_ROOT / "kolla" / "versions" / "source.yml"),
            "--out",
            str(out),
        ]
    )
    assert rc == 0

    rendered = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert rendered["kolla_internal_vip_address"] == "192.0.2.20"
    assert rendered["openstack_release"] == "2024.1"
    assert rendered["docker_registry"] == "registry.example:5000"
    assert rendered["enable_cinder"] == "yes"


def test_clouds_yaml_written_0600(tmp_path: Path, sample_outputs_file: Path) -> None:
    out = tmp_path / "clouds.yaml"
    rc = render.main(
        [
            "clouds",
            "--outputs",
            str(sample_outputs_file),
            "--passwords",
            str(FIXTURES / "passwords-fixture.yml"),
            "--out",
            str(out),
        ]
    )
    assert rc == 0

    mode = stat.S_IMODE(out.stat().st_mode)
    assert mode == 0o600

    clouds = yaml.safe_load(out.read_text(encoding="utf-8"))
    auth = clouds["clouds"]["eph"]["auth"]
    assert auth["auth_url"] == "http://192.0.2.20:5000"
    assert auth["password"] == "unit-test-placeholder-value"
