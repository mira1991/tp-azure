# Objets NetBox PERMANENTS — uniquement des data sources.
#
# Ces objets (site, tenant, cluster, groupe de VLAN, VLAN, préfixes, VRF,
# rôle, plateforme, tags permanents) ne sont jamais créés ni détruits par ce
# projet : un "terraform destroy" de ce state ne peut par construction pas
# les supprimer (voir aussi scripts/check-destroy-plan.py qui le vérifie sur
# chaque plan de destruction).
#
# Aucune ID numérique NetBox n'est codée en dur : tout est résolu par nom.
# Chaque data source du provider échoue si zéro ou plusieurs objets
# correspondent, ce qui fait échouer la pipeline avec un message explicite.

data "netbox_site" "this" {
  name = var.netbox_site
}

data "netbox_tenant" "this" {
  name = var.netbox_tenant
}

data "netbox_cluster" "this" {
  name = var.netbox_cluster
}

data "netbox_vlan_group" "this" {
  name = var.netbox_vlan_group
}

data "netbox_device_role" "vm_role" {
  name = var.netbox_vm_role
}

data "netbox_platform" "this" {
  name = var.netbox_platform
}

data "netbox_vrf" "this" {
  count = var.netbox_vrf == "" ? 0 : 1
  name  = var.netbox_vrf
}

# Tags permanents : lus (donc validés) — jamais créés ni supprimés ici.
data "netbox_tag" "permanent" {
  for_each = toset(local.netbox_fields_config.permanent_tags)
  name     = each.value
}

# VLAN de chaque rôle réseau utilisé par le profil, résolu par nom DANS le
# groupe de VLAN (garantit l'unicité de la recherche).
data "netbox_vlan" "roles" {
  for_each = toset(local.used_network_roles)

  name     = lookup(var.network_role_vlans, each.value, "")
  group_id = tonumber(data.netbox_vlan_group.this.id)

  lifecycle {
    precondition {
      condition     = lookup(var.network_role_vlans, each.value, "") != ""
      error_message = "Le rôle réseau '${each.value}' est requis par le profil '${var.deployment_profile}' mais n'a pas de VLAN mappé (variable network_role_vlans / NETWORK_ROLE_${upper(each.value)})."
    }
  }
}

# Préfixes actifs associés au VLAN de chaque rôle (et à la VRF le cas
# échéant). La recherche DOIT retourner exactement un préfixe : les
# postconditions font échouer le plan avec un message explicite sinon
# (zéro résultat, ou plusieurs sans règle de priorité).
data "netbox_prefixes" "roles" {
  for_each = toset(local.used_network_roles)

  filter {
    name  = "vlan_id"
    value = data.netbox_vlan.roles[each.value].id
  }

  filter {
    name  = "status"
    value = "active"
  }

  dynamic "filter" {
    for_each = var.netbox_vrf == "" ? [] : [1]
    content {
      name  = "vrf_id"
      value = data.netbox_vrf.this[0].id
    }
  }

  lifecycle {
    postcondition {
      condition     = length(self.prefixes) > 0
      error_message = "Aucun préfixe actif trouvé pour le VLAN du rôle réseau '${each.value}' (VLAN '${lookup(var.network_role_vlans, each.value, "?")}')."
    }

    postcondition {
      condition     = length(self.prefixes) <= 1
      error_message = "Plusieurs préfixes actifs correspondent au VLAN du rôle réseau '${each.value}' : aucune règle de priorité n'est définie, corriger NetBox."
    }
  }
}

# Détail du préfixe retenu (custom fields d'override : bridge, gateway, mtu…),
# résolu par CIDR + VRF — combinaison unique dans NetBox.
data "netbox_prefix" "role_details" {
  for_each = toset(local.used_network_roles)

  prefix = one(data.netbox_prefixes.roles[each.value].prefixes).prefix
  vrf_id = var.netbox_vrf == "" ? null : tonumber(data.netbox_vrf.this[0].id)
}
