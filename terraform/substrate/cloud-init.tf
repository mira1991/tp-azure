# Génération et téléversement des données cloud-init (snippets Proxmox).
#
# La configuration réseau (network-config v1) consomme DIRECTEMENT
# netbox_available_ip_address.*.ip_address : c'est l'arête qui garantit que
# les IP NetBox ne sont libérées qu'après destruction des VM Proxmox.
#
# Aucun secret durable n'est placé ici (donc ni dans les snippets ni dans le
# state) : uniquement la clé PUBLIQUE SSH et des paramètres système. Les
# secrets (passwords Kolla, credentials) sont gérés par les jobs GitLab/Vault.

locals {
  # NIC de chaque VM, dans l'ordre du profil (== index Proxmox / ethN).
  vm_nics = {
    for name, vm in local.virtual_machines : name => [
      for nic_index, role in vm.networks : {
        name    = "eth${nic_index}"
        role    = role
        mac     = lower(local.interfaces["${name}/${role}"].mac_address)
        mtu     = local.networks[role].mtu
        address = local.networks[role].allocate_ip ? netbox_available_ip_address.interfaces["${name}/${role}"].ip_address : null
        gateway = local.networks[role].use_gateway ? local.networks[role].gateway : null
        routes  = local.networks[role].static_routes
      }
    ]
  }
}

resource "proxmox_virtual_environment_file" "user_data" {
  for_each = local.proxmox_vms

  content_type = "snippets"
  datastore_id = var.proxmox_snippets_storage
  node_name    = local.placement[each.key]

  source_raw {
    file_name = "${each.key}-user-data.yml"
    data = templatefile("${path.module}/templates/cloud-init.yml.tftpl", {
      hostname        = each.key
      fqdn            = local.global_search_domain != "" ? "${each.key}.${local.global_search_domain}" : each.key
      username        = var.ssh_username
      ssh_public_key  = trimspace(var.ssh_public_key)
      ntp_servers     = local.global_ntp_servers
      apt_proxy_url   = var.apt_proxy_url
      ca_certificates = var.ca_certificates
    })
  }
}

resource "proxmox_virtual_environment_file" "network_config" {
  for_each = local.proxmox_vms

  content_type = "snippets"
  datastore_id = var.proxmox_snippets_storage
  node_name    = local.placement[each.key]

  source_raw {
    file_name = "${each.key}-network-config.yml"
    data = templatefile("${path.module}/templates/network-config.yml.tftpl", {
      nics          = local.vm_nics[each.key]
      dns_servers   = local.global_dns_servers
      search_domain = local.global_search_domain
    })
  }

  lifecycle {
    precondition {
      condition     = local.networks["management"].gateway != null
      error_message = "Passerelle du réseau management introuvable : renseigner le custom field NetBox mappé (config/netbox-fields.yml) ou gateway_override/gateway_host_offset dans config/network-roles.yml."
    }
  }
}
