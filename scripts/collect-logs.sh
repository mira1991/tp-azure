#!/usr/bin/env bash
# Collecte des logs des nœuds pour l'artefact de diagnostic.
# Usage : collect-logs.sh <outputs.json> <répertoire de sortie>
# Lecture seule : n'altère aucune ressource.
set -euo pipefail

OUTPUTS_FILE="${1:?usage: collect-logs.sh <outputs.json> <out_dir>}"
OUT_DIR="${2:?usage: collect-logs.sh <outputs.json> <out_dir>}"

mkdir -p "${OUT_DIR}"

SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

mapfile -t TARGETS < <(jq -r '.ssh_targets.value[]' "${OUTPUTS_FILE}")

for target in "${TARGETS[@]}"; do
  host_dir="${OUT_DIR}/${target#*@}"
  mkdir -p "${host_dir}"
  echo "Collecte: ${target}"
  ssh "${SSH_OPTS[@]}" "${target}" 'sudo journalctl --no-pager -n 2000' \
    > "${host_dir}/journal.log" 2>"${host_dir}/journal.err" || true
  ssh "${SSH_OPTS[@]}" "${target}" 'sudo docker ps -a --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null' \
    > "${host_dir}/docker-ps.txt" 2>/dev/null || true
  ssh "${SSH_OPTS[@]}" "${target}" 'sudo sh -c "tail -n 500 /var/log/kolla/*/*.log 2>/dev/null"' \
    > "${host_dir}/kolla-tails.log" 2>/dev/null || true
  ssh "${SSH_OPTS[@]}" "${target}" 'ip -j addr && ip -j route' \
    > "${host_dir}/network.json" 2>/dev/null || true
done

echo "Logs collectés dans ${OUT_DIR}"
