#!/usr/bin/env python3
"""Détection (lecture seule) de ressources orphelines ou expirées.

Modes :
  --mode environment : liste les objets NetBox et Proxmox portant le tag de
      l'environnement donné, et les compare (optionnellement) au state
      Terraform pour identifier les orphelins hors state.
  --mode expired : liste les environnements NetBox dont le custom field
      expires_at est dépassé (consommé par la pipeline planifiée de TTL).

Ce script NE SUPPRIME RIEN : la remédiation passe par
generate-import-blocks.py puis terraform import / terraform destroy
(procédure docs/RECOVERY.md).
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
from pathlib import Path
from typing import Any

import requests


def netbox_get_all(session: requests.Session, base_url: str, path: str, params: dict[str, str]) -> list[dict]:
    results: list[dict] = []
    url: str | None = f"{base_url.rstrip('/')}/api/{path}/"
    query: dict[str, str] | None = {**params, "limit": "200"}
    while url:
        response = session.get(url, params=query, timeout=30)
        response.raise_for_status()
        payload = response.json()
        results.extend(payload["results"])
        url = payload.get("next")
        query = None
    return results


def build_netbox_session() -> tuple[requests.Session, str]:
    url = os.environ.get("NETBOX_URL", "")
    token = os.environ.get("NETBOX_TOKEN", "")
    if not url or not token:
        raise SystemExit("NETBOX_URL et NETBOX_TOKEN sont requis.")
    session = requests.Session()
    session.headers["Authorization"] = f"Token {token}"
    session.headers["Accept"] = "application/json"
    return session, url


def proxmox_list_vms() -> list[dict]:
    url = os.environ.get("PROXMOX_API_URL", "")
    token_id = os.environ.get("PROXMOX_TOKEN_ID", "")
    token_secret = os.environ.get("PROXMOX_TOKEN_SECRET", "")
    if not url or not token_id or not token_secret:
        return []
    verify = os.environ.get("PROXMOX_INSECURE", "false") != "true"
    response = requests.get(
        f"{url.rstrip('/')}/cluster/resources",
        params={"type": "vm"},
        headers={"Authorization": f"PVEAPIToken={token_id}={token_secret}"},
        verify=verify,
        timeout=30,
    )
    response.raise_for_status()
    return list(response.json().get("data", []))


def state_resource_ids(state_json: Path | None) -> set[str]:
    """IDs (en chaîne) des ressources présentes dans le state Terraform."""
    if state_json is None or not state_json.exists():
        return set()
    with state_json.open(encoding="utf-8") as handle:
        state = json.load(handle)
    ids: set[str] = set()

    def walk(module: dict[str, Any]) -> None:
        for resource in module.get("resources", []):
            value = resource.get("values", {})
            if "id" in value and value["id"] is not None:
                ids.add(str(value["id"]))
        for child in module.get("child_modules", []):
            walk(child)

    walk(state.get("values", {}).get("root_module", {}))
    return ids


def mode_environment(args: argparse.Namespace) -> dict[str, Any]:
    session, base_url = build_netbox_session()
    tag = f"environment-{args.environment_id}"
    proxmox_tag = f"environment_{args.environment_id}"

    netbox_vms = netbox_get_all(session, base_url, "virtualization/virtual-machines", {"tag": tag})
    netbox_interfaces = netbox_get_all(session, base_url, "virtualization/interfaces", {"tag": tag})
    netbox_ips = netbox_get_all(session, base_url, "ipam/ip-addresses", {"tag": tag})

    proxmox_vms = [vm for vm in proxmox_list_vms() if proxmox_tag in (vm.get("tags") or "").split(";")]

    known_ids = state_resource_ids(args.state_json)

    def classify(items: list[dict], kind: str) -> list[dict]:
        rows = []
        for item in items:
            item_id = str(item.get("id", item.get("vmid", "")))
            rows.append(
                {
                    "kind": kind,
                    "id": item_id,
                    "name": item.get("name", ""),
                    "display": item.get("display", item.get("name", "")),
                    "address": item.get("address", ""),
                    "node": item.get("node", ""),
                    "in_state": bool(known_ids) and item_id in known_ids,
                }
            )
        return rows

    inventory = (
        classify(netbox_vms, "netbox_virtual_machine")
        + classify(netbox_interfaces, "netbox_interface")
        + classify(netbox_ips, "netbox_ip_address")
        + classify(proxmox_vms, "proxmox_vm")
    )
    orphans = [row for row in inventory if known_ids and not row["in_state"]]

    return {
        "mode": "environment",
        "environment_id": args.environment_id,
        "resources": inventory,
        "orphans": orphans,
        "state_compared": bool(known_ids),
    }


def mode_expired(args: argparse.Namespace) -> dict[str, Any]:
    session, base_url = build_netbox_session()
    now = datetime.datetime.now(datetime.UTC)
    vms = netbox_get_all(session, base_url, "virtualization/virtual-machines", {"tag": "eph"})

    expired: dict[str, dict[str, Any]] = {}
    for vm in vms:
        fields = vm.get("custom_fields") or {}
        expires_raw = fields.get(args.expires_field) or ""
        env_name = fields.get("environment_name") or ""
        env_id = fields.get("environment_id") or ""
        if not expires_raw or not env_id:
            continue
        try:
            expires = datetime.datetime.fromisoformat(str(expires_raw).replace("Z", "+00:00"))
        except ValueError:
            continue
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=datetime.UTC)
        if expires < now:
            expired[str(env_id)] = {
                "environment_id": str(env_id),
                "environment_name": env_name,
                "expires_at": str(expires_raw),
            }

    return {
        "mode": "expired",
        "expired_environments": sorted(expired.values(), key=lambda e: e["environment_id"]),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["environment", "expired"], required=True)
    parser.add_argument("--environment-id", type=int, help="Requis en mode environment.")
    parser.add_argument(
        "--state-json", type=Path, default=None, help="terraform show -json du state substrate."
    )
    parser.add_argument("--expires-field", default="expires_at", help="Nom du custom field d'expiration.")
    parser.add_argument("--out", type=Path, default=None, help="Fichier de rapport JSON.")
    parser.add_argument(
        "--fail-on-orphans", action="store_true", help="Code retour 2 si des orphelins existent."
    )
    args = parser.parse_args(argv)

    if args.mode == "environment":
        if args.environment_id is None:
            parser.error("--environment-id est requis en mode environment.")
        report = mode_environment(args)
    else:
        report = mode_expired(args)

    rendered = json.dumps(report, indent=2, sort_keys=True)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)

    if args.mode == "environment" and args.fail_on_orphans and report["orphans"]:
        print(f"ERREUR: {len(report['orphans'])} ressource(s) orpheline(s) détectée(s).", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
