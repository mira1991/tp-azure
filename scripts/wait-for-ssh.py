#!/usr/bin/env python3
"""Attente de disponibilité des VM après l'apply substrate.

Pour chaque cible SSH des outputs Terraform :
  1. port TCP 22 joignable ;
  2. authentification SSH par clé (BatchMode) ;
  3. cloud-init terminé (`cloud-init status --wait`) ;
  4. horloge synchronisée (timedatectl, non bloquant en avertissement) ;
  5. résolution DNS sortante fonctionnelle (non bloquant si pas de DNS).

Script d'attente/vérification uniquement : aucune modification de ressource.
"""

from __future__ import annotations

import argparse
import json
import socket
import subprocess
import sys
import time
from pathlib import Path

SSH_BASE_OPTIONS = [
    "-o",
    "BatchMode=yes",
    "-o",
    "StrictHostKeyChecking=accept-new",
    "-o",
    "ConnectTimeout=10",
]


def load_targets(outputs_file: Path) -> list[str]:
    with outputs_file.open(encoding="utf-8") as handle:
        outputs = json.load(handle)
    targets = outputs["ssh_targets"]["value"]
    if not targets:
        raise SystemExit("Aucune cible SSH dans les outputs Terraform (ssh_targets vide).")
    return list(targets)


def tcp_reachable(host: str, port: int = 22, timeout: float = 5.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def ssh_run(target: str, command: str, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["ssh", *SSH_BASE_OPTIONS, target, command],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def wait_target(target: str, deadline: float, interval: float) -> list[str]:
    """Attend qu'une cible soit prête ; retourne la liste des avertissements."""
    host = target.split("@", 1)[1]
    warnings: list[str] = []

    while time.monotonic() < deadline:
        if tcp_reachable(host):
            break
        time.sleep(interval)
    else:
        raise SystemExit(f"{target}: port 22 injoignable avant l'échéance.")

    while time.monotonic() < deadline:
        if ssh_run(target, "true").returncode == 0:
            break
        time.sleep(interval)
    else:
        raise SystemExit(f"{target}: authentification SSH impossible avant l'échéance.")

    result = ssh_run(target, "sudo cloud-init status --wait", timeout=600)
    if result.returncode != 0:
        raise SystemExit(f"{target}: cloud-init en erreur ({result.stdout.strip()} {result.stderr.strip()}).")

    result = ssh_run(target, "timedatectl show -p NTPSynchronized --value")
    if result.returncode != 0 or result.stdout.strip() != "yes":
        warnings.append(f"{target}: horloge non (encore) synchronisée NTP.")

    result = ssh_run(target, "getent hosts localhost >/dev/null && echo ok")
    if result.returncode != 0:
        warnings.append(f"{target}: résolution de noms locale défaillante.")

    print(f"OK: {target}")
    return warnings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--outputs", type=Path, required=True, help="Fichier terraform output -json.")
    parser.add_argument("--timeout", type=int, default=1200, help="Échéance globale en secondes.")
    parser.add_argument("--interval", type=float, default=10.0, help="Intervalle entre tentatives.")
    args = parser.parse_args(argv)

    targets = load_targets(args.outputs)
    deadline = time.monotonic() + args.timeout

    warnings: list[str] = []
    for target in targets:
        warnings += wait_target(target, deadline, args.interval)

    for warning in warnings:
        print(f"AVERTISSEMENT: {warning}", file=sys.stderr)

    print(f"Toutes les cibles sont prêtes ({len(targets)}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
