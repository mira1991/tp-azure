#!/usr/bin/env python3
"""Garde-fou du plan de destruction (contrôle d'acceptation).

Analyse un plan Terraform JSON (`terraform show -json plan.bin`) et échoue si
le plan prévoit de détruire un type de ressource hors de la liste blanche des
objets ÉPHÉMÈRES du state. Garantit structurellement qu'aucun VLAN, préfixe,
site ou tenant permanent (des data sources, jamais des ressources) ne peut
être supprimé — et rend le contrôle exécutable et visible en pipeline.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ALLOWED_DESTROY_TYPES: dict[str, frozenset[str]] = {
    "substrate": frozenset(
        {
            "netbox_virtual_machine",
            "netbox_interface",
            "netbox_available_ip_address",
            "netbox_primary_ip",
            "netbox_tag",
            "proxmox_virtual_environment_vm",
            "proxmox_virtual_environment_file",
            "terraform_data",
        }
    ),
    # Tout objet du state openstack-config est éphémère par construction.
    "openstack-config": frozenset(
        {
            "openstack_identity_project_v3",
            "openstack_identity_user_v3",
            "openstack_identity_role_v3",
            "openstack_identity_role_assignment_v3",
            "openstack_compute_flavor_v2",
            "openstack_images_image_v2",
            "openstack_networking_addressscope_v2",
            "openstack_networking_subnetpool_v2",
            "openstack_networking_network_v2",
            "openstack_networking_subnet_v2",
            "openstack_networking_router_v2",
            "openstack_networking_router_interface_v2",
            "openstack_networking_secgroup_v2",
            "openstack_networking_secgroup_rule_v2",
            "openstack_blockstorage_volume_type_v3",
            "openstack_compute_quotaset_v2",
            "openstack_blockstorage_quotaset_v3",
            "openstack_networking_quota_v2",
            "openstack_dns_zone_v2",
            "openstack_dns_recordset_v2",
            "openstack_lb_loadbalancer_v2",
            "openstack_lb_listener_v2",
            "openstack_lb_pool_v2",
            "openstack_lb_monitor_v2",
            "openstack_keymanager_secret_v1",
        }
    ),
}

FORBIDDEN_TYPES = frozenset(
    {
        "netbox_vlan",
        "netbox_prefix",
        "netbox_site",
        "netbox_tenant",
        "netbox_cluster",
        "netbox_vlan_group",
        "netbox_vrf",
        "netbox_device_role",
        "netbox_platform",
    }
)


def check_plan(plan: dict, state: str) -> list[str]:
    allowed = ALLOWED_DESTROY_TYPES[state]
    errors: list[str] = []

    for change in plan.get("resource_changes", []):
        actions = change.get("change", {}).get("actions", [])
        if "delete" not in actions:
            continue
        resource_type = change.get("type", "")
        address = change.get("address", "")
        if resource_type in FORBIDDEN_TYPES:
            errors.append(
                f"INTERDIT: le plan détruit '{address}' de type '{resource_type}' "
                "(objet permanent NetBox — le teardown est corrompu, NE PAS APPLIQUER)."
            )
        elif resource_type not in allowed:
            errors.append(
                f"INATTENDU: le plan détruit '{address}' de type '{resource_type}' "
                f"hors liste blanche du state '{state}'."
            )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan-json", type=Path, required=True, help="Sortie de terraform show -json.")
    parser.add_argument("--state", choices=sorted(ALLOWED_DESTROY_TYPES), required=True)
    args = parser.parse_args(argv)

    with args.plan_json.open(encoding="utf-8") as handle:
        plan = json.load(handle)

    errors = check_plan(plan, args.state)
    if errors:
        for error in errors:
            print(f"ERREUR: {error}", file=sys.stderr)
        return 1

    deletions = sum(
        1
        for change in plan.get("resource_changes", [])
        if "delete" in change.get("change", {}).get("actions", [])
    )
    print(f"Plan de destruction conforme ({deletions} suppressions, toutes en liste blanche).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
