terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "3.11.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}
