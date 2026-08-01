# Transformation du profil YAML (config/profiles.yml) en une map normalisée
# de VM et d'interfaces. Aucune ressource n'est dupliquée manuellement par
# rôle : tout est dérivé ici puis consommé par for_each.

locals {
  profiles_config      = yamldecode(file("${path.module}/../../config/profiles.yml"))
  network_roles_config = yamldecode(file("${path.module}/../../config/network-roles.yml"))
  netbox_fields_config = yamldecode(file("${path.module}/../../config/netbox-fields.yml"))

  environment_name = format("eph-osk-%s-%d", var.purpose_short, var.environment_id)

  role_catalog = local.profiles_config.roles
  profile      = local.profiles_config.profiles[var.deployment_profile]

  # Groupes de nœuds actifs du profil (storage peut être désactivé).
  node_groups = {
    for role, spec in local.profile.nodes : role => spec
    if tobool(try(spec.enabled, true)) && tonumber(spec.count) > 0
  }

  # Map normalisée des VM : clé = nom complet
  # eph-osk-<purpose_short>-<environment_id>-<role_court>-<index>.
  virtual_machines = merge([
    for role, spec in local.node_groups : {
      for i in range(tonumber(spec.count)) :
      format("%s-%s-%02d", local.environment_name, local.role_catalog[role].short, i + 1) => {
        role                  = role
        role_index            = i + 1
        vcpu                  = tonumber(spec.vcpu)
        memory_mb             = tonumber(spec.memory_mb)
        disk_gb               = tonumber(spec.disk_gb)
        nested_virtualization = tobool(try(spec.nested_virtualization, false))
        networks              = spec.networks
      }
    }
  ]...)

  vm_names   = sort(keys(local.virtual_machines))
  vm_ordinal = { for idx, name in local.vm_names : name => idx }

  # Map normalisée des interfaces : clé = "<vm>/<rôle réseau>".
  # L'ordre des réseaux dans le profil fixe l'index de carte Proxmox, le nom
  # Linux (ethN, imposé par la correspondance MAC dans cloud-init
  # network-config) et l'interface NetBox : correspondance déterministe
  # rôle réseau <-> index NIC <-> MAC <-> nom Linux <-> NetBox <-> Kolla.
  interfaces = merge([
    for vm_name, vm in local.virtual_machines : {
      for nic_index, network_role in vm.networks :
      "${vm_name}/${network_role}" => {
        vm_name      = vm_name
        network_role = network_role
        nic_index    = nic_index
        linux_name   = "eth${nic_index}"
        # MAC déterministe et localement administrée (OUI Proxmox BC:24:11),
        # sans collision au sein d'un environnement : (env, vm, nic).
        mac_address = format(
          "BC:24:11:%02X:%02X:%02X",
          var.environment_id % 256,
          local.vm_ordinal[vm_name],
          nic_index,
        )
      }
    }
  ]...)

  # Seules les interfaces des rôles avec allocate_ip reçoivent une IP NetBox
  # (le réseau provider reste une interface L2 pure pour Neutron).
  interfaces_requiring_ip = {
    for key, nic in local.interfaces : key => nic
    if local.network_role_settings[nic.network_role].allocate_ip
  }

  # Placement déterministe des VM sur les nœuds Proxmox.
  #   spread : répartit chaque rôle sur les nœuds (round-robin par rôle) ;
  #   pack   : concentre tout sur le premier nœud ;
  #   manual : mapping fourni (par nom de VM, sinon par rôle).
  placement = {
    for name, vm in local.virtual_machines : name => (
      var.placement_strategy == "manual"
      ? lookup(var.placement_manual, name, lookup(var.placement_manual, vm.role, null))
      : (
        var.placement_strategy == "pack"
        ? var.proxmox_target_nodes[0]
        : var.proxmox_target_nodes[(vm.role_index - 1) % length(var.proxmox_target_nodes)]
      )
    )
  }

  # Phase "allocate" : le for_each des VM Proxmox est vidé, dans le MÊME
  # state — les allocations NetBox existent déjà et sont conservées lors du
  # passage en phase "full".
  proxmox_vms = var.terraform_phase == "full" ? local.virtual_machines : {}

  # Tags Proxmox (caractères autorisés : [a-z0-9_.-]).
  proxmox_tags = sort([
    for tag in concat(
      [
        "eph",
        "openstack",
        "managed_by_terraform",
        format("environment_%d", var.environment_id),
      ],
      var.pipeline_id == "" ? [] : [format("pipeline_%s", var.pipeline_id)],
      var.expires_at == "" ? [] : [format("expires_%s", replace(substr(var.expires_at, 0, 10), "-", "_"))],
    ) : replace(lower(tag), "/[^a-z0-9_.-]/", "-")
  ])
}
