# Interfaces NetBox temporaires, une par NIC de chaque VM du profil.
#
# La clé "<vm>/<rôle réseau>" est la même que celle des allocations IP et des
# NIC Proxmox : la correspondance rôle réseau / index NIC / MAC / nom Linux /
# interface NetBox / cloud-init / Kolla est entièrement déterministe
# (locals-topology.tf) et ne repose jamais sur l'ordre d'énumération Linux.

resource "netbox_interface" "interfaces" {
  for_each = local.interfaces

  virtual_machine_id = tonumber(netbox_virtual_machine.nodes[each.value.vm_name].id)
  name               = each.value.linux_name
  description        = "${each.value.network_role} (VLAN ${local.networks[each.value.network_role].vlan_name})"
  enabled            = true
  mode               = "access"
  untagged_vlan      = local.networks[each.value.network_role].vlan_id
  mtu                = local.networks[each.value.network_role].mtu
  mac_address        = upper(each.value.mac_address)
  tags               = local.netbox_tag_names
}
