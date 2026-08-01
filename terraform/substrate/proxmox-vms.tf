# VM Proxmox — feuilles du graphe de dépendances.
#
# Les VM consomment les IP NetBox via local.vm_nics (cloud-init.tf), qui
# référence netbox_available_ip_address.interfaces[...].ip_address : Terraform
# crée donc les allocations AVANT les VM, et au destroy supprime les VM AVANT
# de libérer les IP. C'est le mécanisme central du teardown fiable.

resource "proxmox_virtual_environment_vm" "nodes" {
  for_each = local.proxmox_vms

  name      = each.key
  node_name = local.placement[each.key]
  vm_id     = var.proxmox_vmid_base > 0 ? var.proxmox_vmid_base + local.vm_ordinal[each.key] : null
  pool_id   = var.proxmox_pool == "" ? null : var.proxmox_pool

  description = format(
    "Ephemeral OpenStack %s node — %s. Owner: %s. Expires: %s. Managed by Terraform (GitLab pipeline %s).",
    each.value.role, local.environment_name, var.environment_owner, var.expires_at, var.pipeline_id,
  )
  tags = local.proxmox_tags

  on_boot         = true
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  started         = true
  stop_on_destroy = true

  # Délais explicites : clone/démarrage longs sur stockage partagé, et arrêt
  # forcé rapide au teardown.
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_start_vm    = 600
  timeout_shutdown_vm = 300
  timeout_stop_vm     = 300

  agent {
    # Le template DOIT embarquer qemu-guest-agent (docs/PROXMOX.md) ;
    # cloud-init l'active au premier boot.
    enabled = true
    timeout = "10m"
  }

  operating_system {
    type = "l26"
  }

  # Console série : requise par la plupart des images cloud Ubuntu.
  serial_device {}

  clone {
    vm_id     = var.proxmox_template_vmid
    node_name = var.proxmox_template_node == "" ? null : var.proxmox_template_node
    full      = true
  }

  cpu {
    cores   = each.value.vcpu
    sockets = 1
    # KVM imbriqué : les computes exposent les extensions VMX/SVM via
    # cpu type "host" (vérifié ensuite par ansible/playbooks/validate-kvm.yml).
    type = each.value.nested_virtualization ? "host" : var.proxmox_cpu_type
  }

  memory {
    dedicated = each.value.memory_mb
  }

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = each.value.disk_gb
    discard      = "on"
    iothread     = true
  }

  dynamic "network_device" {
    for_each = local.vm_nics[each.key]
    content {
      bridge      = local.networks[network_device.value.role].proxmox_bridge
      model       = "virtio"
      mac_address = upper(network_device.value.mac)
      vlan_id     = local.networks[network_device.value.role].vlan_tag_on_bridge ? local.networks[network_device.value.role].vlan_vid : null
      mtu         = network_device.value.mtu == 1500 ? null : network_device.value.mtu
    }
  }

  initialization {
    datastore_id         = var.proxmox_storage
    interface            = "ide2"
    user_data_file_id    = proxmox_virtual_environment_file.user_data[each.key].id
    network_data_file_id = proxmox_virtual_environment_file.network_config[each.key].id
  }

  lifecycle {
    precondition {
      condition     = local.placement[each.key] != null
      error_message = "Placement manuel incomplet : aucun nœud Proxmox pour '${each.key}' (ni son rôle '${each.value.role}') dans placement_manual."
    }

    precondition {
      condition     = alltrue([for nic in local.vm_nics[each.key] : local.networks[nic.role].proxmox_bridge != null])
      error_message = "Bridge Proxmox non résolu pour au moins un rôle réseau de '${each.key}' : renseigner le custom field NetBox mappé ou proxmox_bridge dans config/network-roles.yml."
    }

    precondition {
      condition     = !each.value.nested_virtualization || contains(["compute", "aio"], each.value.role)
      error_message = "nested_virtualization n'est attendu que sur les rôles compute/aio ('${each.key}')."
    }
  }
}
