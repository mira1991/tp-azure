#!/usr/bin/env python3
"""Transformation des outputs Terraform en artefacts consommables.

Sous-commandes (transformation d'outputs uniquement — aucune ressource n'est
créée ni supprimée par ce script) :

  inventory  : écrit l'inventaire Kolla (groupes d'hôtes Terraform + groupes
               de services du multinode packagé avec la version de
               kolla-ansible installée) et les host_vars.
  manifest   : écrit le manifeste JSON de l'environnement.
  globals    : rend kolla/globals.yml.j2 avec le contexte Terraform + le
               fichier de versions + les variables de registry.
  clouds     : écrit un clouds.yaml admin temporaire (0600) à partir de
               passwords.yml — à détruire par trap dans le job appelant.
"""

from __future__ import annotations

import argparse
import json
import os
import stat
import sys
from pathlib import Path
from typing import Any

import jinja2
import yaml

SERVICE_GROUPS_MARKER = "[baremetal:children]"


def load_outputs(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        outputs = json.load(handle)
    return {name: payload["value"] for name, payload in outputs.items()}


def find_packaged_multinode() -> Path:
    """Localise le fichier multinode fourni par la version installée de kolla-ansible."""
    candidates = [
        Path(prefix) / "share" / "kolla-ansible" / "ansible" / "inventory" / "multinode"
        for prefix in (sys.prefix, "/usr/local", "/usr")
    ]
    venv = os.environ.get("VIRTUAL_ENV")
    if venv:
        candidates.insert(0, Path(venv) / "share" / "kolla-ansible" / "ansible" / "inventory" / "multinode")
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise SystemExit(
        "multinode introuvable : kolla-ansible ne semble pas installé "
        f"(candidats : {', '.join(str(c) for c in candidates)})."
    )


def cmd_inventory(args: argparse.Namespace) -> int:
    outputs = load_outputs(args.outputs)
    inventory_dir: Path = args.out_dir
    host_vars_dir = inventory_dir / "host_vars"
    host_vars_dir.mkdir(parents=True, exist_ok=True)

    multinode_path = args.kolla_multinode or find_packaged_multinode()
    packaged = multinode_path.read_text(encoding="utf-8")
    if SERVICE_GROUPS_MARKER not in packaged:
        raise SystemExit(
            f"{multinode_path}: marqueur '{SERVICE_GROUPS_MARKER}' absent — version kolla inattendue."
        )
    service_groups = packaged[packaged.index(SERVICE_GROUPS_MARKER) :]

    inventory = outputs["kolla_inventory"].rstrip() + "\n\n" + service_groups
    (inventory_dir / "multinode").write_text(inventory, encoding="utf-8")

    for host, content in outputs["kolla_host_vars"].items():
        (host_vars_dir / f"{host}.yml").write_text(content, encoding="utf-8")

    print(f"Inventaire écrit dans {inventory_dir} ({len(outputs['kolla_host_vars'])} host_vars).")
    return 0


def cmd_manifest(args: argparse.Namespace) -> int:
    outputs = load_outputs(args.outputs)
    manifest = {
        "environment": outputs["environment_manifest"],
        "nodes": outputs["nodes"],
        "netbox_resources": outputs["netbox_resources"],
        "proxmox_resources": outputs["proxmox_resources"],
        "internal_vip_address": outputs["internal_vip_address"],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Manifeste écrit : {args.out}")
    return 0


def cmd_globals(args: argparse.Namespace) -> int:
    outputs = load_outputs(args.outputs)
    with args.versions.open(encoding="utf-8") as handle:
        versions = yaml.safe_load(handle)

    context: dict[str, Any] = dict(outputs["globals_context"])
    context.update(versions)
    context.update(
        {
            "docker_registry": os.environ.get("KOLLA_REGISTRY", ""),
            "docker_namespace": os.environ.get("KOLLA_REGISTRY_NAMESPACE", "kolla"),
            "enable_octavia": os.environ.get("RUN_OCTAVIA_TESTS", "false") == "true",
            "enable_designate": os.environ.get("RUN_DESIGNATE_TESTS", "false") == "true",
            "enable_cinder": os.environ.get("RUN_CINDER_TESTS", "false") == "true",
        }
    )

    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(args.template.parent)),
        undefined=jinja2.StrictUndefined,
        keep_trailing_newline=True,
    )
    rendered = env.get_template(args.template.name).render(**context)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(rendered, encoding="utf-8")
    print(f"globals.yml rendu : {args.out}")
    return 0


def cmd_clouds(args: argparse.Namespace) -> int:
    outputs = load_outputs(args.outputs)
    with args.passwords.open(encoding="utf-8") as handle:
        passwords = yaml.safe_load(handle)

    admin_password = passwords.get("keystone_admin_password")
    if not admin_password:
        raise SystemExit("keystone_admin_password absent de passwords.yml.")

    vip = outputs["globals_context"]["kolla_internal_vip_address"]
    clouds = {
        "clouds": {
            "eph": {
                "auth": {
                    "auth_url": f"http://{vip}:5000",
                    "username": "admin",
                    "password": admin_password,
                    "project_name": "admin",
                    "user_domain_name": "Default",
                    "project_domain_name": "Default",
                },
                "region_name": "RegionOne",
                "interface": "internal",
                "identity_api_version": 3,
            }
        }
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.touch(mode=0o600, exist_ok=True)
    args.out.chmod(stat.S_IRUSR | stat.S_IWUSR)
    args.out.write_text(yaml.safe_dump(clouds, default_flow_style=False), encoding="utf-8")
    print(f"clouds.yaml écrit (0600) : {args.out} — à supprimer par trap dans le job.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_inventory = subparsers.add_parser("inventory", help="Inventaire Kolla + host_vars.")
    p_inventory.add_argument("--outputs", type=Path, required=True)
    p_inventory.add_argument("--out-dir", type=Path, required=True)
    p_inventory.add_argument("--kolla-multinode", type=Path, default=None)
    p_inventory.set_defaults(func=cmd_inventory)

    p_manifest = subparsers.add_parser("manifest", help="Manifeste d'environnement JSON.")
    p_manifest.add_argument("--outputs", type=Path, required=True)
    p_manifest.add_argument("--out", type=Path, required=True)
    p_manifest.set_defaults(func=cmd_manifest)

    p_globals = subparsers.add_parser("globals", help="Rendu de globals.yml.")
    p_globals.add_argument("--outputs", type=Path, required=True)
    p_globals.add_argument("--template", type=Path, required=True)
    p_globals.add_argument("--versions", type=Path, required=True)
    p_globals.add_argument("--out", type=Path, required=True)
    p_globals.set_defaults(func=cmd_globals)

    p_clouds = subparsers.add_parser("clouds", help="clouds.yaml admin temporaire.")
    p_clouds.add_argument("--outputs", type=Path, required=True)
    p_clouds.add_argument("--passwords", type=Path, required=True)
    p_clouds.add_argument("--out", type=Path, required=True)
    p_clouds.set_defaults(func=cmd_clouds)

    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
