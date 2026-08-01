# Résolution des paramètres réseau par rôle.
#
# Sources par ordre de priorité :
#   1. custom fields NetBox du préfixe (noms mappés dans config/netbox-fields.yml) ;
#   2. config/network-roles.yml (roles.<role> puis defaults) ;
#   3. défauts codés (mtu 1500).

locals {
  used_network_roles = distinct(flatten([for vm in local.virtual_machines : vm.networks]))

  network_role_settings = {
    for role in local.used_network_roles : role => merge(
      local.network_roles_config.defaults,
      try(local.network_roles_config.roles[role], {}),
    )
  }

  global_dns_servers   = length(var.dns_servers) > 0 ? var.dns_servers : try(local.network_roles_config.global.dns_servers, [])
  global_search_domain = var.search_domain != "" ? var.search_domain : try(local.network_roles_config.global.search_domain, "")
  global_ntp_servers   = length(var.ntp_servers) > 0 ? var.ntp_servers : try(local.network_roles_config.global.ntp_servers, [])

  prefix_override_fields = try(local.netbox_fields_config.prefix_overrides, {})

  # Préfixe unique retenu pour chaque rôle (unicité garantie par les
  # postconditions de data.netbox_prefixes.roles ; one() échoue sinon).
  role_prefix = {
    for role in local.used_network_roles :
    role => one(data.netbox_prefixes.roles[role].prefixes)
  }

  # Custom fields du préfixe NetBox de chaque rôle (map vide si absents).
  prefix_custom_fields = {
    for role in local.used_network_roles :
    role => try(data.netbox_prefix.role_details[role].custom_fields, tomap({}))
  }

  # Lecture d'un override : try(coalesce(x), null) neutralise à la fois les
  # clés absentes, les valeurs null et les chaînes vides.
  cf_bridge = {
    for role in local.used_network_roles : role => try(
      coalesce(lookup(local.prefix_custom_fields[role], try(local.prefix_override_fields.proxmox_bridge, "-"), null)), null
    )
  }
  cf_gateway = {
    for role in local.used_network_roles : role => try(
      coalesce(lookup(local.prefix_custom_fields[role], try(local.prefix_override_fields.gateway, "-"), null)), null
    )
  }
  cf_mtu = {
    for role in local.used_network_roles : role => try(
      tonumber(coalesce(lookup(local.prefix_custom_fields[role], try(local.prefix_override_fields.mtu, "-"), null))), null
    )
  }

  networks = {
    for role in local.used_network_roles : role => {
      network_role  = role
      vlan_name     = var.network_role_vlans[role]
      vlan_id       = tonumber(data.netbox_vlan.roles[role].id)
      vlan_vid      = tonumber(local.role_prefix[role].vlan_vid)
      prefix_id     = local.role_prefix[role].id
      prefix_cidr   = local.role_prefix[role].prefix
      prefix_length = tonumber(split("/", local.role_prefix[role].prefix)[1])
      vrf_id        = var.netbox_vrf == "" ? null : tonumber(data.netbox_vrf.this[0].id)
      tenant_id     = tonumber(data.netbox_tenant.this.id)
      site_id       = tonumber(data.netbox_site.this.id)

      allocate_ip        = tobool(local.network_role_settings[role].allocate_ip)
      use_gateway        = tobool(local.network_role_settings[role].use_gateway)
      vlan_tag_on_bridge = tobool(local.network_role_settings[role].vlan_tag_on_bridge)
      static_routes      = try(local.network_role_settings[role].static_routes, [])

      # Peut valoir null : la précondition des VM Proxmox échoue alors avec
      # un message explicite (validations.tf ne peut que produire un warning).
      proxmox_bridge = try(coalesce(
        local.cf_bridge[role],
        try(local.network_role_settings[role].proxmox_bridge, null),
      ), null)

      mtu = try(coalesce(
        local.cf_mtu[role],
        try(tonumber(local.network_role_settings[role].mtu), null),
      ), 1500)

      # Passerelle : custom field NetBox > gateway_override du YAML > calcul
      # cidrhost(prefix, offset). Ce calcul concerne UNIQUEMENT l'adresse de
      # l'équipement de routage permanent — jamais l'allocation d'IP de VM,
      # qui passe exclusivement par netbox_available_ip_address.
      gateway = !tobool(local.network_role_settings[role].use_gateway) ? null : try(coalesce(
        local.cf_gateway[role],
        try(coalesce(local.network_role_settings[role].gateway_override), null),
        cidrhost(
          local.role_prefix[role].prefix,
          tonumber(try(local.network_role_settings[role].gateway_host_offset, 1)),
        ),
      ), null)
    }
  }
}
