# Configuration des providers du state "substrate".
#
# Les credentials ne sont JAMAIS déclarés en variables Terraform : ils sont
# injectés par variables d'environnement dans les jobs GitLab
# (scripts/terraform-env.sh) afin de ne figurer ni dans les fichiers .tf,
# ni dans les plans archivés :
#   - NetBox  : NETBOX_SERVER_URL, NETBOX_API_TOKEN
#   - Proxmox : PROXMOX_VE_ENDPOINT, PROXMOX_VE_API_TOKEN, PROXMOX_VE_INSECURE

provider "netbox" {
  # Entièrement configuré par variables d'environnement.
}

provider "proxmox" {
  # endpoint / api_token / insecure via variables d'environnement.
  #
  # L'accès SSH aux nœuds Proxmox est requis par le provider bpg pour
  # téléverser les snippets cloud-init (user-data / network-config).
  # La clé est fournie via ssh-agent dans les jobs CI (jamais en variable
  # Terraform).
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
