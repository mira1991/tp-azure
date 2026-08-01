#!/usr/bin/env bash
# Entrypoint de l'image toolbox : sélectionne le venv Kolla-Ansible
# (KOLLA_VENV=source|target, défaut source) puis exécute la commande du job.
set -euo pipefail

KOLLA_VENV="${KOLLA_VENV:-source}"
case "${KOLLA_VENV}" in
  source | target)
    export PATH="/opt/kolla/${KOLLA_VENV}/bin:${PATH}"
    export VIRTUAL_ENV="/opt/kolla/${KOLLA_VENV}"
    ;;
  none)
    : # outillage seul, sans kolla-ansible dans le PATH
    ;;
  *)
    echo "KOLLA_VENV invalide: '${KOLLA_VENV}' (source|target|none)" >&2
    exit 1
    ;;
esac

exec "$@"
