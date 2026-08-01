# Données d'inventaire Kolla-Ansible dérivées de la topologie et des
# allocations IP NetBox. Le rendu est exposé en outputs ; la pipeline le
# matérialise avec :
#   terraform output -raw kolla_inventory > artifacts/inventory/multinode.hosts
# puis scripts/render-terraform-outputs.py fusionne les groupes de services
# du multinode fourni par la version de Kolla-Ansible installée.

locals {
  management_ip = {
    for name in local.vm_names :
    name => split("/", netbox_available_ip_address.interfaces["${name}/management"].ip_address)[0]
  }

  internal_vip_ip = split("/", netbox_available_ip_address.internal_vip.ip_address)[0]

  deploy_nodes  = [for n in local.vm_names : n if local.virtual_machines[n].role == "deploy"]
  aio_nodes     = [for n in local.vm_names : n if local.virtual_machines[n].role == "aio"]
  control_nodes = [for n in local.vm_names : n if contains(["control", "aio"], local.virtual_machines[n].role)]
  compute_nodes = [for n in local.vm_names : n if contains(["compute", "aio"], local.virtual_machines[n].role)]
  storage_only  = [for n in local.vm_names : n if local.virtual_machines[n].role == "storage"]

  kolla_groups = {
    control = local.control_nodes
    # Le groupe network est porté par les nœuds disposant d'une interface
    # provider (neutron_external_interface) — voir docs/KOLLA.md.
    network    = [for n in local.vm_names : n if contains(local.virtual_machines[n].networks, "provider") && local.virtual_machines[n].role != "deploy"]
    compute    = local.compute_nodes
    monitoring = local.control_nodes
    storage    = length(local.storage_only) > 0 ? local.storage_only : (length(local.aio_nodes) > 0 ? local.aio_nodes : local.control_nodes)
    deployment = local.deploy_nodes
  }

  deploy_bastion_ip = length(local.deploy_nodes) > 0 ? local.management_ip[local.deploy_nodes[0]] : ""

  # Nom Linux de chaque rôle réseau, par nœud (peut différer d'un rôle de
  # nœud à l'autre : les host_vars portent donc les interfaces Kolla).
  node_interface_roles = {
    for name, vm in local.virtual_machines :
    name => { for idx, role in vm.networks : role => "eth${idx}" }
  }

  host_vars_rendered = {
    for name, vm in local.virtual_machines : name => templatefile("${path.module}/templates/host-vars.yml.tftpl", {
      name          = name
      role          = vm.role
      management_ip = local.management_ip[name]
      ssh_user      = var.ssh_username
      bastion       = (var.ssh_via_deploy_bastion && vm.role != "deploy") ? local.deploy_bastion_ip : ""
      interfaces    = local.node_interface_roles[name]
      interface_ips = {
        for role in vm.networks : role => (
          local.networks[role].allocate_ip
          ? split("/", netbox_available_ip_address.interfaces["${name}/${role}"].ip_address)[0]
          : ""
        )
      }
    })
  }

  kolla_inventory_rendered = templatefile("${path.module}/templates/kolla-inventory.ini.tftpl", {
    groups   = local.kolla_groups
    ssh_user = var.ssh_username
  })

  globals_context = {
    environment_name           = local.environment_name
    environment_id             = tostring(var.environment_id)
    kolla_internal_vip_address = local.internal_vip_ip
    network_interface          = "eth0"
    management_cidr            = local.networks["management"].prefix_cidr
  }
}
