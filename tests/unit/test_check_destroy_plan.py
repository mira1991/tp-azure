"""Tests unitaires du garde-fou de plan de destruction.

Contrôle d'acceptation : le plan de destruction ne doit jamais prévoir la
suppression d'un VLAN, d'un préfixe, d'un site ou d'un tenant permanents.
"""

from __future__ import annotations

from pathlib import Path

from tests.unit.test_validate_inputs import REPO_ROOT, load_script

check = load_script("check-destroy-plan.py")

FIXTURES = REPO_ROOT / "tests" / "fixtures"


def test_good_plan_passes() -> None:
    rc = check.main(["--plan-json", str(FIXTURES / "destroy-plan-good.json"), "--state", "substrate"])
    assert rc == 0


def test_plan_destroying_permanent_objects_fails(capsys) -> None:
    rc = check.main(["--plan-json", str(FIXTURES / "destroy-plan-bad.json"), "--state", "substrate"])
    assert rc == 1
    err = capsys.readouterr().err
    assert "netbox_vlan" in err
    assert "netbox_prefix" in err
    assert "INTERDIT" in err


def test_openstack_types_rejected_in_substrate(tmp_path: Path) -> None:
    plan = tmp_path / "plan.json"
    plan.write_text(
        '{"resource_changes": [{"address": "openstack_networking_network_v2.x",'
        ' "type": "openstack_networking_network_v2", "change": {"actions": ["delete"]}}]}',
        encoding="utf-8",
    )
    assert check.main(["--plan-json", str(plan), "--state", "substrate"]) == 1
    assert check.main(["--plan-json", str(plan), "--state", "openstack-config"]) == 0


def test_update_actions_are_ignored(tmp_path: Path) -> None:
    plan = tmp_path / "plan.json"
    plan.write_text(
        '{"resource_changes": [{"address": "netbox_vlan.perm", "type": "netbox_vlan",'
        ' "change": {"actions": ["update"]}}]}',
        encoding="utf-8",
    )
    assert check.main(["--plan-json", str(plan), "--state", "substrate"]) == 0
