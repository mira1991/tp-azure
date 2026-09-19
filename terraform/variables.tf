###############################################################################
# OpenStack credentials
#
# In CI these are supplied as masked/protected GitLab variables named
# TF_VAR_os_password, TF_VAR_os_user_name, ... so no secret ever lives in git.
###############################################################################

variable "os_auth_url" {
  description = "Keystone authentication endpoint, e.g. https://keystone.example.net:5000/v3"
  type        = string
}

variable "os_region" {
  description = "OpenStack region the resources are created in."
  type        = string
  default     = "RegionOne"
}

variable "os_user_name" {
  description = "OpenStack user name used by Terraform."
  type        = string
}

variable "os_password" {
  description = "Password of the OpenStack user."
  type        = string
  sensitive   = true
}

variable "os_project_name" {
  description = "OpenStack project (tenant) the resources belong to."
  type        = string
}

variable "os_user_domain_name" {
  description = "Keystone domain of the user."
  type        = string
  default     = "Default"
}

variable "os_project_domain_name" {
  description = "Keystone domain of the project."
  type        = string
  default     = "Default"
}

variable "os_cacert_file" {
  description = "Path to a PEM bundle trusted when talking to Keystone. Use it for clouds with a private CA instead of disabling verification."
  type        = string
  default     = null
}

###############################################################################
# Naming and tagging
###############################################################################

variable "project_name" {
  description = "Short name used as a prefix for every resource."
  type        = string
  default     = "tp"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 2-20 characters of lowercase letters, digits or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment. Also used as a resource name suffix."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Extra tags applied to taggable resources."
  type        = list(string)
  default     = []
}

###############################################################################
# Network
###############################################################################

variable "external_network_name" {
  description = "Name of the provider network that carries floating IPs."
  type        = string
  default     = "public"
}

variable "subnet_cidr" {
  description = "CIDR of the private tenant subnet."
  type        = string
  default     = "10.30.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "dns_nameservers" {
  description = "DNS resolvers handed out by DHCP on the private subnet."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

###############################################################################
# Security
###############################################################################

variable "ssh_allowed_cidrs" {
  description = "Source ranges allowed to reach TCP/22. Keep this as narrow as possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "http_allowed_cidrs" {
  description = "Source ranges allowed to reach TCP/80 and TCP/443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

###############################################################################
# Compute
###############################################################################

variable "instance_count" {
  description = "Number of web instances to create."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count must be between 1 and 10."
  }
}

variable "image_name" {
  description = "Name of the Glance image booted by the instances."
  type        = string
  default     = "Ubuntu-22.04"
}

variable "flavor_name" {
  description = "Nova flavor of the instances."
  type        = string
  default     = "m1.small"
}

variable "ssh_public_key" {
  description = "SSH public key injected into the instances. Empty means an existing keypair named <project>-<env> is reused."
  type        = string
  default     = ""
}

variable "assign_floating_ips" {
  description = "Allocate and attach a floating IP to every instance."
  type        = bool
  default     = true
}

variable "data_volume_size" {
  description = "Size in GB of the extra Cinder volume attached to each instance. 0 disables the volume."
  type        = number
  default     = 0
}

variable "availability_zone" {
  description = "Nova availability zone. Null lets the scheduler decide."
  type        = string
  default     = null
}
