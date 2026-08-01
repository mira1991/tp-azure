#!/usr/bin/env python3
"""Validation des entrées du projet (profils, rôles réseau, mapping NetBox).

Rôle strictement limité à la validation (aucune création/suppression de
ressource) :
  - conformité des YAML aux JSON Schemas de config/schema/ ;
  - cohérence croisée : rôles de nœuds connus, réseaux référencés définis,
    premier réseau = management, unicité des noms générés.

Sortie non nulle en cas d'échec, avec messages explicites — utilisé par le
stage `validate` et par les tests unitaires.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import jsonschema
import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent


def load_yaml(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def load_schema(schema_dir: Path, name: str) -> dict[str, Any]:
    with (schema_dir / name).open(encoding="utf-8") as handle:
        return json.load(handle)


def validate_schema(instance: Any, schema: dict[str, Any], label: str) -> list[str]:
    validator = jsonschema.Draft202012Validator(schema)
    errors = []
    for error in sorted(validator.iter_errors(instance), key=lambda e: list(e.absolute_path)):
        path = "/".join(str(part) for part in error.absolute_path) or "<racine>"
        errors.append(f"{label}: {path}: {error.message}")
    return errors


def cross_checks(profiles: dict[str, Any], networks: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    role_catalog = profiles.get("roles", {})
    network_roles = set(networks.get("roles", {}).keys())

    shorts = [spec.get("short") for spec in role_catalog.values()]
    if len(shorts) != len(set(shorts)):
        errors.append("profiles.yml: les codes courts de rôles (roles.*.short) doivent être uniques.")

    for profile_name, profile in profiles.get("profiles", {}).items():
        for node_role, spec in profile.get("nodes", {}).items():
            label = f"profiles.yml: profiles.{profile_name}.nodes.{node_role}"
            if node_role not in role_catalog:
                errors.append(f"{label}: rôle absent du catalogue 'roles'.")
            node_networks = spec.get("networks", [])
            if not node_networks or node_networks[0] != "management":
                errors.append(f"{label}: le premier réseau doit être 'management'.")
            for network in node_networks:
                if network not in network_roles:
                    errors.append(f"{label}: réseau '{network}' absent de config/network-roles.yml.")
            if spec.get("nested_virtualization") and node_role not in ("compute", "aio"):
                errors.append(f"{label}: nested_virtualization réservé aux rôles compute/aio.")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config-dir",
        type=Path,
        default=REPO_ROOT / "config",
        help="Répertoire config/ à valider (défaut : celui du dépôt).",
    )
    args = parser.parse_args(argv)

    config_dir: Path = args.config_dir
    schema_dir = config_dir / "schema"

    errors: list[str] = []

    profiles = load_yaml(config_dir / "profiles.yml")
    networks = load_yaml(config_dir / "network-roles.yml")
    fields = load_yaml(config_dir / "netbox-fields.yml")

    errors += validate_schema(profiles, load_schema(schema_dir, "profiles.schema.json"), "profiles.yml")
    errors += validate_schema(networks, load_schema(schema_dir, "networks.schema.json"), "network-roles.yml")

    example = config_dir / "environments.example.yml"
    if example.exists():
        errors += validate_schema(
            load_yaml(example), load_schema(schema_dir, "environment.schema.json"), "environments.example.yml"
        )

    if not isinstance(fields.get("custom_fields"), dict):
        errors.append("netbox-fields.yml: la clé 'custom_fields' (map) est requise.")
    if not isinstance(fields.get("permanent_tags"), list) or not fields.get("permanent_tags"):
        errors.append("netbox-fields.yml: la clé 'permanent_tags' (liste non vide) est requise.")

    if not errors:
        errors += cross_checks(profiles, networks)

    if errors:
        for error in errors:
            print(f"ERREUR: {error}", file=sys.stderr)
        return 1

    print("Validation des entrées : OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
