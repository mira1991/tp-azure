#!/usr/bin/env bash
# Prépare l'environnement Terraform d'un job GitLab (à SOURCER, pas exécuter) :
#   source scripts/terraform-env.sh <substrate|openstack-config>
#
# - backend HTTP GitLab (TF_HTTP_*) : state, lock POST, unlock DELETE, retries ;
# - credentials providers via variables d'environnement (jamais en TF_VAR ni
#   dans les fichiers .tf) ;
# - TF_VAR_* dérivées des variables fonctionnelles de la pipeline.
#
# Ne JAMAIS activer `set -x` ici : des secrets transitent par l'environnement.

_tf_role="${1:?usage: source scripts/terraform-env.sh <substrate|openstack-config>}"

: "${ENVIRONMENT_ID:?ENVIRONMENT_ID manquant}"
: "${ENVIRONMENT_NAME:?ENVIRONMENT_NAME manquant}"

case "${_tf_role}" in
  substrate)
    export TF_ROOT="terraform/substrate"
    _state_name="${SUBSTRATE_STATE_NAME:-${ENVIRONMENT_NAME}-substrate}"
    ;;
  openstack-config)
    export TF_ROOT="terraform/openstack-config"
    _state_name="${OPENSTACK_STATE_NAME:-${ENVIRONMENT_NAME}-openstack-config}"
    ;;
  *)
    echo "terraform-env.sh: rôle inconnu '${_tf_role}'" >&2
    return 1
    ;;
esac

# ---------------------------------------------------------------------------
# Backend HTTP GitLab
# ---------------------------------------------------------------------------
export TF_HTTP_ADDRESS="${TF_HTTP_ADDRESS:-${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${_state_name}}"
export TF_HTTP_LOCK_ADDRESS="${TF_HTTP_LOCK_ADDRESS:-${TF_HTTP_ADDRESS}/lock}"
export TF_HTTP_UNLOCK_ADDRESS="${TF_HTTP_UNLOCK_ADDRESS:-${TF_HTTP_ADDRESS}/lock}"
export TF_HTTP_LOCK_METHOD="POST"
export TF_HTTP_UNLOCK_METHOD="DELETE"
export TF_HTTP_RETRY_MAX="${TF_HTTP_RETRY_MAX:-6}"
export TF_HTTP_RETRY_WAIT_MIN="${TF_HTTP_RETRY_WAIT_MIN:-2}"
export TF_HTTP_USERNAME="${TF_HTTP_USERNAME:-gitlab-ci-token}"
export TF_HTTP_PASSWORD="${TF_HTTP_PASSWORD:-${CI_JOB_TOKEN}}"

export TF_IN_AUTOMATION="1"
export TF_INPUT="0"

# ---------------------------------------------------------------------------
# Credentials providers (variables d'environnement uniquement)
# ---------------------------------------------------------------------------
if [ "${_tf_role}" = "substrate" ]; then
  export NETBOX_SERVER_URL="${NETBOX_URL:?NETBOX_URL manquant}"
  export NETBOX_API_TOKEN="${NETBOX_TOKEN:?NETBOX_TOKEN manquant}"
  export PROXMOX_VE_ENDPOINT="${PROXMOX_API_URL:?PROXMOX_API_URL manquant}"
  export PROXMOX_VE_API_TOKEN="${PROXMOX_TOKEN_ID:?PROXMOX_TOKEN_ID manquant}=${PROXMOX_TOKEN_SECRET:?PROXMOX_TOKEN_SECRET manquant}"
  export PROXMOX_VE_INSECURE="${PROXMOX_INSECURE:-false}"
fi
# openstack-config : OS_CLOUD/OS_* sont positionnés par le job après
# génération du clouds.yaml temporaire (render-terraform-outputs.py clouds).

# ---------------------------------------------------------------------------
# TF_VAR_* communes
# ---------------------------------------------------------------------------
export TF_VAR_environment_id="${ENVIRONMENT_ID}"

if [ "${_tf_role}" = "substrate" ]; then
  export TF_VAR_purpose_short="${PURPOSE_SHORT:-dev}"
  export TF_VAR_environment_owner="${ENVIRONMENT_OWNER:-}"
  export TF_VAR_environment_purpose="${ENVIRONMENT_PURPOSE:-}"
  export TF_VAR_environment_ttl_hours="${ENVIRONMENT_TTL_HOURS:-48}"
  export TF_VAR_created_at="${CREATED_AT:-}"
  export TF_VAR_expires_at="${EXPIRES_AT:-}"
  export TF_VAR_pipeline_id="${CI_PIPELINE_ID:-}"
  export TF_VAR_pipeline_url="${CI_PIPELINE_URL:-}"
  export TF_VAR_project_path="${CI_PROJECT_PATH:-}"

  export TF_VAR_deployment_profile="${DEPLOYMENT_PROFILE:-minimal}"
  export TF_VAR_placement_strategy="${PLACEMENT_STRATEGY:-spread}"
  export TF_VAR_terraform_phase="${TERRAFORM_PHASE:-full}"

  export TF_VAR_netbox_site="${NETBOX_SITE:?NETBOX_SITE manquant}"
  export TF_VAR_netbox_tenant="${NETBOX_TENANT:?NETBOX_TENANT manquant}"
  export TF_VAR_netbox_cluster="${NETBOX_CLUSTER:?NETBOX_CLUSTER manquant}"
  export TF_VAR_netbox_vlan_group="${NETBOX_VLAN_GROUP:?NETBOX_VLAN_GROUP manquant}"
  export TF_VAR_netbox_vrf="${NETBOX_VRF:-}"
  export TF_VAR_netbox_vm_role="${NETBOX_VM_ROLE:-ephemeral-openstack}"
  export TF_VAR_netbox_platform="${NETBOX_PLATFORM:-ubuntu-22.04}"
  export TF_VAR_netbox_ephemeral_ip_status="${NETBOX_EPHEMERAL_IP_STATUS:-reserved}"

  TF_VAR_network_role_vlans=$(python3 - <<'PYEOF'
import json
import os

roles = {}
for key, value in os.environ.items():
    if key.startswith("NETWORK_ROLE_") and value:
        roles[key.removeprefix("NETWORK_ROLE_").lower()] = value
print(json.dumps(roles))
PYEOF
  )
  export TF_VAR_network_role_vlans

  TF_VAR_proxmox_target_nodes=$(python3 - <<'PYEOF'
import json
import os

nodes = [node.strip() for node in os.environ.get("PROXMOX_TARGET_NODES", "").split(",") if node.strip()]
print(json.dumps(nodes))
PYEOF
  )
  export TF_VAR_proxmox_target_nodes

  export TF_VAR_proxmox_pool="${PROXMOX_POOL:-}"
  export TF_VAR_proxmox_template_vmid="${PROXMOX_TEMPLATE:?PROXMOX_TEMPLATE manquant}"
  export TF_VAR_proxmox_template_node="${PROXMOX_TEMPLATE_NODE:-}"
  export TF_VAR_proxmox_storage="${PROXMOX_STORAGE:?PROXMOX_STORAGE manquant}"
  export TF_VAR_proxmox_snippets_storage="${PROXMOX_SNIPPETS_STORAGE:-local}"
  export TF_VAR_proxmox_ssh_username="${PROXMOX_SSH_USERNAME:-root}"

  export TF_VAR_ssh_username="${NODE_SSH_USERNAME:-kolla}"
  export TF_VAR_ssh_public_key="${SSH_PUBLIC_KEY:?SSH_PUBLIC_KEY manquant}"
else
  export TF_VAR_environment_name="${ENVIRONMENT_NAME}"
  export TF_VAR_enable_designate="${RUN_DESIGNATE_TESTS:-false}"
  export TF_VAR_enable_octavia="${RUN_OCTAVIA_TESTS:-false}"
fi

unset _tf_role _state_name
