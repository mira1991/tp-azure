# Outputs consommés par la pipeline (inventaire Kolla, tests, rapports).
# Aucun mot de passe ni secret : passwords.yml et credentials OpenStack sont
# gérés exclusivement par les jobs GitLab / Vault.

output "nodes" {
  description = "Topologie complète : rôle, IP management, interfaces (IP/MAC/VLAN/bridge/nom Linux) par VM."
  value = {
    for name, vm in local.virtual_machines : name => {
      role          = vm.role
      management_ip = local.management_ip[name]
      proxmox_node  = local.placement[name]
      interfaces = {
        for nic in local.vm_nics[name] : nic.role => {
          ip_address  = nic.address == null ? null : split("/", nic.address)[0]
          cidr        = nic.address
          mac_address = upper(nic.mac)
          vlan_id     = local.networks[nic.role].vlan_vid
          bridge      = local.networks[nic.role].proxmox_bridge
          linux_name  = nic.name
          mtu         = nic.mtu
        }
      }
    }
  }
}

output "kolla_inventory" {
  description = "Groupes d'hôtes de l'inventaire Kolla-Ansible (multinode, partie hôtes)."
  value       = local.kolla_inventory_rendered
}

output "kolla_host_vars" {
  description = "host_vars Kolla-Ansible rendus, par nom de nœud."
  value       = local.host_vars_rendered
}

output "globals_context" {
  description = "Contexte injecté dans kolla/globals.yml.j2 (VIP interne, interfaces par défaut)."
  value       = local.globals_context
}

output "environment_manifest" {
  description = "Manifeste de l'environnement (traçabilité, rapports, TTL)."
  value = {
    environment_id     = var.environment_id
    environment_name   = local.environment_name
    purpose_short      = var.purpose_short
    purpose            = var.environment_purpose
    owner              = var.environment_owner
    deployment_profile = var.deployment_profile
    placement_strategy = var.placement_strategy
    terraform_phase    = var.terraform_phase
    created_at         = var.created_at
    expires_at         = var.expires_at
    ttl_hours          = var.environment_ttl_hours
    pipeline_id        = var.pipeline_id
    pipeline_url       = var.pipeline_url
    project_path       = var.project_path
    node_count         = length(local.virtual_machines)
    internal_vip       = local.internal_vip_ip
    managed_by         = "terraform-gitlab"
  }
}

output "netbox_resources" {
  description = "Identifiants NetBox des objets éphémères (rapports, détection d'orphelins)."
  value = {
    virtual_machines = { for name, vm in netbox_virtual_machine.nodes : name => vm.id }
    interfaces       = { for key, nic in netbox_interface.interfaces : key => nic.id }
    ip_addresses = {
      for key, ip in netbox_available_ip_address.interfaces : key => {
        id         = ip.id
        ip_address = ip.ip_address
      }
    }
    internal_vip = {
      id         = netbox_available_ip_address.internal_vip.id
      ip_address = netbox_available_ip_address.internal_vip.ip_address
    }
    environment_tag = netbox_tag.environment.name
  }
}

output "proxmox_resources" {
  description = "Identifiants Proxmox des VM (rapports, détection d'orphelins). Vide en phase allocate."
  value = {
    for name, vm in proxmox_virtual_environment_vm.nodes : name => {
      vm_id     = vm.vm_id
      node_name = vm.node_name
    }
  }
}

output "management_ips" {
  description = "IP management par nœud."
  value       = local.management_ip
}

output "internal_vip_address" {
  description = "kolla_internal_vip_address réservée dans NetBox."
  value       = local.internal_vip_ip
}

output "ssh_targets" {
  description = "Cibles SSH (user@ip) pour l'attente de disponibilité et les tests."
  value       = [for name in local.vm_names : "${var.ssh_username}@${local.management_ip[name]}"]
}
