#!/usr/bin/env python3
"""Génération de blocs `import` Terraform pour la reprise sur incident.

Consomme le rapport de detect-orphans.py (mode environment) et produit un
fichier imports.tf à déposer dans terraform/substrate/, afin de réintégrer
les ressources orphelines dans le state PUIS de les détruire proprement via
`terraform destroy` (workflow docs/RECOVERY.md) :

    détection -> blocs import -> terraform plan -> terraform apply
    -> terraform destroy

Ce script n'appelle aucune API de suppression.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HEADER = """\
# Blocs d'import générés par scripts/generate-import-blocks.py — reprise sur
# incident uniquement (docs/RECOVERY.md). À déposer dans terraform/substrate/
# puis : terraform plan (contrôle) ; terraform apply (import) ; supprimer ce
# fichier ; terraform destroy.
"""


def interface_key(name: str, description: str) -> str | None:
    """Reconstruit la clé for_each '<vm>/<rôle>' d'une interface NetBox.

    La description des interfaces créées par ce projet commence par le rôle
    réseau ('<rôle> (VLAN ...)') — voir netbox-interfaces.tf.
    """
    match = re.match(r"^([a-z][a-z0-9_]*) ", description + " ")
    if not match:
        return None
    return match.group(1)


def build_blocks(report: dict) -> list[str]:
    blocks: list[str] = []
    interfaces_by_id: dict[str, dict] = {}

    for row in report.get("resources", []):
        if row["kind"] == "netbox_interface":
            interfaces_by_id[row["id"]] = row

    for row in report.get("orphans", []) or report.get("resources", []):
        kind, rid, name = row["kind"], row["id"], row["name"]
        if kind == "netbox_virtual_machine":
            blocks.append(f'import {{\n  to = netbox_virtual_machine.nodes["{name}"]\n  id = "{rid}"\n}}')
        elif kind == "netbox_interface":
            vm = row.get("display", "").split(":", 1)[0].strip() or "UNKNOWN-VM"
            role = interface_key(name, row.get("display", "")) or "UNKNOWN-ROLE"
            blocks.append(
                f'import {{\n  to = netbox_interface.interfaces["{vm}/{role}"]\n  id = "{rid}"\n}}'
                "\n# NOTE: vérifier la clé <vm>/<rôle> ci-dessus avant apply."
            )
        elif kind == "netbox_ip_address":
            blocks.append(
                f"# IP {row.get('address', '?')} (id {rid}) : import vers\n"
                f'# netbox_available_ip_address.interfaces["<vm>/<rôle>"] — compléter la clé :\n'
                "import {\n  to = netbox_available_ip_address"
                f'.interfaces["UNKNOWN-VM/UNKNOWN-ROLE"]\n  id = "{rid}"\n}}'
            )
        elif kind == "proxmox_vm":
            node = row.get("node", "UNKNOWN-NODE")
            blocks.append(
                f'import {{\n  to = proxmox_virtual_environment_vm.nodes["{name}"]\n  id = "{node}/{rid}"\n}}'
            )
    return blocks


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True, help="Rapport JSON de detect-orphans.py.")
    parser.add_argument("--out", type=Path, required=True, help="Fichier imports.tf à générer.")
    parser.add_argument(
        "--orphans-only",
        action="store_true",
        help="Ne générer que les ressources absentes du state (défaut : toutes).",
    )
    args = parser.parse_args(argv)

    with args.report.open(encoding="utf-8") as handle:
        report = json.load(handle)

    if args.orphans_only:
        report = {"resources": report.get("resources", []), "orphans": report.get("orphans", [])}
        rows = report["orphans"]
    else:
        rows = report.get("resources", [])
    if not rows:
        print("Aucune ressource à importer.")
        return 0

    working = dict(report)
    if not args.orphans_only:
        working["orphans"] = []

    blocks = build_blocks(working)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(HEADER + "\n" + "\n\n".join(blocks) + "\n", encoding="utf-8")
    print(f"{len(blocks)} bloc(s) d'import écrits dans {args.out} — relire avant apply.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
