# Entrées du state "substrate".
# Les valeurs sont fournies par la pipeline via TF_VAR_* (scripts/terraform-env.sh).

# --------------------------------------------------------------------------
# Identité de l'environnement
# --------------------------------------------------------------------------

variable "environment_id" {
  description = "Identifiant unique de l'environnement éphémère (défaut CI : CI_PIPELINE_IID)."
  type        = number

  validation {
    condition     = var.environment_id > 0 && floor(var.environment_id) == var.environment_id
    error_message = "environment_id doit être un entier strictement positif."
  }
}

variable "purpose_short" {
  description = "Code court de l'usage (upg, dev, ci...), utilisé dans les noms : eph-osk-<purpose_short>-<environment_id>."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.purpose_short))
    error_message = "purpose_short : 2 à 8 caractères [a-z0-9] (compatibilité DNS/Proxmox/NetBox/Kolla)."
  }
}

variable "environment_owner" {
  description = "Propriétaire de l'environnement (login GitLab)."
  type        = string
  default     = ""
}

variable "environment_purpose" {
  description = "Description libre de l'usage de l'environnement."
  type        = string
  default     = ""
}

variable "environment_ttl_hours" {
  description = "Durée de vie prévue de l'environnement, en heures."
  type        = number
  default     = 48
}

variable "created_at" {
  description = "Horodatage de création (RFC3339), calculé une fois par la pipeline."
  type        = string
  default     = ""
}

variable "expires_at" {
  description = "Horodatage d'expiration (RFC3339), calculé par la pipeline (created_at + TTL)."
  type        = string
  default     = ""
}

variable "pipeline_id" {
  description = "CI_PIPELINE_ID de la pipeline qui gère cet environnement (traçabilité)."
  type        = string
  default     = ""
}

variable "pipeline_url" {
  description = "URL de la pipeline GitLab (traçabilité NetBox)."
  type        = string
  default     = ""
}

variable "project_path" {
  description = "Chemin du projet GitLab (traçabilité NetBox)."
  type        = string
  default     = ""
}

# --------------------------------------------------------------------------
# Topologie
# --------------------------------------------------------------------------

variable "deployment_profile" {
  description = "Profil de déploiement défini dans config/profiles.yml."
  type        = string
  default     = "minimal"
}

variable "placement_strategy" {
  description = "Stratégie de placement des VM sur les nœuds Proxmox."
  type        = string
  default     = "spread"

  validation {
    condition     = contains(["spread", "pack", "manual"], var.placement_strategy)
    error_message = "placement_strategy : spread, pack ou manual."
  }
}

variable "placement_manual" {
  description = "Placement manuel : map nom-de-VM-ou-rôle => nœud Proxmox (utilisé si placement_strategy = manual)."
  type        = map(string)
  default     = {}
}

variable "terraform_phase" {
  description = <<-EOT
    Mode de compatibilité en deux phases DANS LE MÊME STATE :
      - "allocate" : crée uniquement VM NetBox + interfaces + réservations IP ;
      - "full"     : crée aussi les VM Proxmox (les allocations existantes
                     du state sont conservées telles quelles).
    Le mode nominal est un unique apply en phase "full".
  EOT
  type        = string
  default     = "full"

  validation {
    condition     = contains(["allocate", "full"], var.terraform_phase)
    error_message = "terraform_phase : allocate ou full."
  }
}

# --------------------------------------------------------------------------
# NetBox — objets permanents recherchés en data sources (jamais créés ici)
# --------------------------------------------------------------------------

variable "netbox_site" {
  description = "Nom du site NetBox existant."
  type        = string
}

variable "netbox_tenant" {
  description = "Nom du tenant NetBox existant."
  type        = string
}

variable "netbox_cluster" {
  description = "Nom du cluster de virtualisation NetBox existant (Proxmox)."
  type        = string
}

variable "netbox_vlan_group" {
  description = "Nom du groupe de VLAN NetBox contenant les VLAN des rôles réseau."
  type        = string
}

variable "netbox_vrf" {
  description = "Nom de la VRF NetBox (vide = table de routage globale)."
  type        = string
  default     = ""
}

variable "netbox_vm_role" {
  description = "Nom du rôle NetBox (device role) appliqué aux VM éphémères — doit exister."
  type        = string
  default     = "ephemeral-openstack"
}

variable "netbox_platform" {
  description = "Nom de la plateforme NetBox appliquée aux VM éphémères — doit exister."
  type        = string
  default     = "ubuntu-22.04"
}

variable "netbox_assign_site_to_vms" {
  description = "Renseigner site_id sur les VM NetBox (mettre à false si votre cluster NetBox impose son propre site)."
  type        = bool
  default     = true
}

variable "network_role_vlans" {
  description = "Map rôle réseau => nom du VLAN NetBox (variables CI NETWORK_ROLE_*)."
  type        = map(string)
}

variable "netbox_ephemeral_ip_status" {
  description = "Statut NetBox des IP éphémères pendant la vie de l'environnement."
  type        = string
  default     = "reserved"

  validation {
    condition     = contains(["reserved", "active"], var.netbox_ephemeral_ip_status)
    error_message = "netbox_ephemeral_ip_status : reserved ou active."
  }
}

# --------------------------------------------------------------------------
# Proxmox
# --------------------------------------------------------------------------

variable "proxmox_target_nodes" {
  description = "Nœuds Proxmox cibles pour le placement (ordre significatif)."
  type        = list(string)

  validation {
    condition     = length(var.proxmox_target_nodes) > 0
    error_message = "proxmox_target_nodes doit contenir au moins un nœud."
  }
}

variable "proxmox_pool" {
  description = "Pool Proxmox dans lequel placer les VM (vide = aucun)."
  type        = string
  default     = ""
}

variable "proxmox_template_vmid" {
  description = "VMID du template cloud-init à cloner (image Ubuntu avec qemu-guest-agent, voir docs/PROXMOX.md)."
  type        = number
}

variable "proxmox_template_node" {
  description = "Nœud hébergeant le template (vide = même nœud que la VM cible)."
  type        = string
  default     = ""
}

variable "proxmox_storage" {
  description = "Datastore Proxmox pour les disques et le volume cloud-init."
  type        = string
}

variable "proxmox_snippets_storage" {
  description = "Datastore Proxmox acceptant le content-type 'snippets' (user-data/network-config)."
  type        = string
  default     = "local"
}

variable "proxmox_cpu_type" {
  description = "Type CPU des VM non-compute. Les computes utilisent toujours 'host' (KVM imbriqué)."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "proxmox_vmid_base" {
  description = "Base de VMID déterministe (0 = laisser Proxmox choisir). Chaque VM reçoit base + ordinal."
  type        = number
  default     = 0
}

variable "proxmox_ssh_username" {
  description = "Utilisateur SSH des nœuds Proxmox (upload des snippets via le provider, clé via ssh-agent)."
  type        = string
  default     = "root"
}

# --------------------------------------------------------------------------
# Invités (cloud-init)
# --------------------------------------------------------------------------

variable "ssh_username" {
  description = "Utilisateur initial créé par cloud-init sur les VM."
  type        = string
  default     = "kolla"
}

variable "ssh_public_key" {
  description = "Clé publique SSH autorisée pour l'utilisateur initial. Aucune clé privée ne transite par Terraform."
  type        = string

  validation {
    condition     = can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)) ", trimspace(var.ssh_public_key)))
    error_message = "ssh_public_key doit être une clé publique OpenSSH valide."
  }
}

variable "dns_servers" {
  description = "Serveurs DNS des VM (surcharge config/network-roles.yml:global.dns_servers)."
  type        = list(string)
  default     = []
}

variable "search_domain" {
  description = "Domaine de recherche DNS des VM (surcharge config/network-roles.yml:global.search_domain)."
  type        = string
  default     = ""
}

variable "ntp_servers" {
  description = "Serveurs NTP des VM (surcharge config/network-roles.yml:global.ntp_servers)."
  type        = list(string)
  default     = []
}

variable "apt_proxy_url" {
  description = "Proxy APT à configurer via cloud-init (vide = aucun)."
  type        = string
  default     = ""
}

variable "ca_certificates" {
  description = "Certificats CA internes (PEM) à installer via cloud-init. Ce ne sont pas des secrets."
  type        = list(string)
  default     = []
}

variable "ssh_via_deploy_bastion" {
  description = "true : Ansible/SSH atteint les nœuds via le nœud deploy en ProxyJump (le runner ne doit alors joindre que le nœud deploy)."
  type        = bool
  default     = false
}
