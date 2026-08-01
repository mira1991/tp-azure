# Entrées du state "openstack-config".
# Aucun secret ici : l'authentification passe par OS_CLOUD/OS_* (providers.tf).

variable "environment_id" {
  description = "Identifiant de l'environnement éphémère (le même que le substrate)."
  type        = number
}

variable "environment_name" {
  description = "Nom complet de l'environnement (eph-osk-<usage>-<id>)."
  type        = string
}

# --------------------------------------------------------------------------
# Identité / projet de smoke tests
# --------------------------------------------------------------------------

variable "smoke_project_description" {
  description = "Description du projet de test."
  type        = string
  default     = "Projet de smoke tests éphémère — managed-by: terraform-gitlab"
}

# --------------------------------------------------------------------------
# Flavors
# --------------------------------------------------------------------------

variable "flavors" {
  description = "Flavors créées pour les tests."
  type = map(object({
    vcpus     = number
    ram_mb    = number
    disk_gb   = number
    is_public = optional(bool, true)
  }))
  default = {
    "eph.tiny"   = { vcpus = 1, ram_mb = 512, disk_gb = 1 }
    "eph.small"  = { vcpus = 1, ram_mb = 2048, disk_gb = 10 }
    "eph.medium" = { vcpus = 2, ram_mb = 4096, disk_gb = 20 }
  }
}

# --------------------------------------------------------------------------
# Image de test
# --------------------------------------------------------------------------

variable "test_image_name" {
  description = "Nom de l'image de test (CirrOS)."
  type        = string
  default     = "eph-cirros"
}

variable "test_image_source_url" {
  description = "URL de téléchargement de l'image de test (miroir interne recommandé)."
  type        = string
  default     = "https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img"
}

variable "test_image_local_path" {
  description = "Chemin local de l'image de test (prioritaire sur l'URL si non vide — utile sans accès Internet)."
  type        = string
  default     = ""
}

# --------------------------------------------------------------------------
# Réseau provider (externe)
# --------------------------------------------------------------------------

variable "create_external_network" {
  description = "Créer le réseau externe provider (false si le lab n'a pas de réseau provider routable)."
  type        = bool
  default     = true
}

variable "provider_network_type" {
  description = "Type du réseau provider externe : flat ou vlan."
  type        = string
  default     = "flat"

  validation {
    condition     = contains(["flat", "vlan"], var.provider_network_type)
    error_message = "provider_network_type : flat ou vlan."
  }
}

variable "provider_physical_network" {
  description = "physical_network Neutron du réseau provider (aligné avec globals.yml)."
  type        = string
  default     = "physnet1"
}

variable "provider_segmentation_id" {
  description = "VLAN ID du réseau provider (requis si provider_network_type = vlan)."
  type        = number
  default     = null
}

variable "external_cidr" {
  description = "CIDR du sous-réseau externe (doit correspondre au réseau provider physique)."
  type        = string
  default     = "203.0.113.0/24"
}

variable "external_gateway_ip" {
  description = "Passerelle du sous-réseau externe (vide = premier hôte du CIDR)."
  type        = string
  default     = ""
}

variable "external_pool_start" {
  description = "Début de la plage d'allocation flottante du réseau externe."
  type        = string
  default     = "203.0.113.100"
}

variable "external_pool_end" {
  description = "Fin de la plage d'allocation flottante du réseau externe."
  type        = string
  default     = "203.0.113.200"
}

# --------------------------------------------------------------------------
# Réseau self-service de smoke tests
# --------------------------------------------------------------------------

variable "smoke_network_cidr" {
  description = "CIDR du réseau self-service de smoke tests."
  type        = string
  default     = "10.250.0.0/24"
}

variable "smoke_dns_nameservers" {
  description = "DNS annoncés sur le sous-réseau de smoke tests."
  type        = list(string)
  default     = []
}

# --------------------------------------------------------------------------
# Address scopes / subnet pools
# --------------------------------------------------------------------------

variable "subnet_pool_prefixes" {
  description = "Préfixes du subnet pool self-service."
  type        = list(string)
  default     = ["10.251.0.0/16"]
}

# --------------------------------------------------------------------------
# Quotas du projet de test
# --------------------------------------------------------------------------

variable "smoke_quotas" {
  description = "Quotas appliqués au projet de smoke tests."
  type = object({
    instances     = optional(number, 10)
    cores         = optional(number, 20)
    ram_mb        = optional(number, 40960)
    volumes       = optional(number, 10)
    gigabytes     = optional(number, 100)
    snapshots     = optional(number, 10)
    networks      = optional(number, 10)
    subnets       = optional(number, 10)
    routers       = optional(number, 5)
    ports         = optional(number, 50)
    floatingips   = optional(number, 10)
    secgroups     = optional(number, 20)
    secgroup_rule = optional(number, 100)
  })
  default = {}
}

# --------------------------------------------------------------------------
# Services optionnels
# --------------------------------------------------------------------------

variable "enable_designate" {
  description = "Créer les objets Designate de test (zone DNS)."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Nom de la zone Designate de test (FQDN terminé par un point)."
  type        = string
  default     = "eph-smoke.test."
}

variable "dns_zone_email" {
  description = "Email SOA de la zone Designate de test."
  type        = string
  default     = "admin@example.invalid"
}

variable "enable_octavia" {
  description = "Créer les objets Octavia de test (load balancer + listener + pool + monitor)."
  type        = bool
  default     = false
}

variable "enable_barbican" {
  description = "Créer le secret Barbican de validation (payload non sensible)."
  type        = bool
  default     = false
}
