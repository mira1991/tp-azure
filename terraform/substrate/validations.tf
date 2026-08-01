# Validations globales.
#
# Les invariants BLOQUANTS sont portés par des preconditions attachées aux
# ressources (netbox-vms.tf, proxmox-vms.tf, cloud-init.tf, data-netbox.tf) :
# un échec y interrompt le plan/apply. Les blocs check ci-dessous produisent
# des avertissements visibles dans les logs de pipeline pour les incohérences
# non fatales, plus une ressource terraform_data qui transforme en erreurs
# dures les invariants non rattachables à une ressource métier.

resource "terraform_data" "invariants" {
  input = local.environment_name

  lifecycle {
    precondition {
      condition     = contains(keys(local.profiles_config.profiles), var.deployment_profile)
      error_message = "Profil '${var.deployment_profile}' inconnu : profils disponibles = ${join(", ", keys(local.profiles_config.profiles))}."
    }

    precondition {
      condition     = alltrue([for vm in values(local.virtual_machines) : contains(keys(local.role_catalog), vm.role)])
      error_message = "Un rôle de nœud du profil '${var.deployment_profile}' est absent du catalogue roles de config/profiles.yml."
    }

    precondition {
      condition     = length(local.kolla_groups.deployment) >= 1
      error_message = "Le profil doit contenir au moins un nœud de rôle 'deploy'."
    }

    precondition {
      condition     = length(local.kolla_groups.network) >= 1
      error_message = "Aucun nœud ne porte le réseau 'provider' : le groupe network de Kolla (neutron_external_interface) serait vide."
    }

    precondition {
      condition     = alltrue([for role in local.used_network_roles : local.networks[role].mtu >= 1280 && local.networks[role].mtu <= 9216])
      error_message = "MTU incohérent (attendu entre 1280 et 9216) sur au moins un rôle réseau."
    }

    precondition {
      condition = (
        var.proxmox_vmid_base == 0
        || length(local.virtual_machines) == length(distinct([for name in local.vm_names : var.proxmox_vmid_base + local.vm_ordinal[name]]))
      )
      error_message = "proxmox_vmid_base produit des VMID en collision."
    }

    precondition {
      condition     = var.placement_strategy != "manual" || alltrue([for name, node in local.placement : node != null])
      error_message = "placement_manual incomplet : chaque VM (ou son rôle) doit être mappée sur un nœud Proxmox."
    }
  }
}

check "vlan_prefix_alignment" {
  assert {
    condition = alltrue([
      for role in local.used_network_roles :
      local.networks[role].prefix_length >= 8 && local.networks[role].prefix_length <= 30
    ])
    error_message = "Longueur de préfixe inhabituelle (hors /8-/30) sur au moins un rôle réseau : vérifier les préfixes NetBox."
  }
}

check "spread_placement_effective" {
  assert {
    condition = (
      var.placement_strategy != "spread"
      || length(var.proxmox_target_nodes) > 1
      || length(local.virtual_machines) <= 2
    )
    error_message = "placement_strategy=spread avec un seul nœud Proxmox : les nœuds critiques partageront le même hyperviseur."
  }
}

check "ttl_defined" {
  assert {
    condition     = var.expires_at != ""
    error_message = "expires_at vide : le TTL ne sera pas tracé dans NetBox/Proxmox (la pipeline le calcule normalement)."
  }
}
