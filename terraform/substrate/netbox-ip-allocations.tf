# Réservation DYNAMIQUE des adresses IP dans NetBox.
#
# L'allocation passe exclusivement par la ressource dédiée
# netbox_available_ip_address (prochaine IP libre du préfixe) : pas de liste
# d'IP côté client, pas de cidrhost(), pas de compteur, pas de fichier
# statique. L'adresse retournée vit dans le state Terraform et est consommée
# DIRECTEMENT par les VM Proxmox (cloud-init.tf / proxmox-vms.tf), ce qui
# crée l'arête de dépendance essentielle au teardown :
#
#   create :  interface NetBox -> IP NetBox -> VM Proxmox
#   destroy : VM Proxmox -> IP NetBox -> interface NetBox -> VM NetBox
#
# La libération d'une IP n'intervient donc jamais avant la destruction de la
# VM Proxmox qui la consomme. Ne JAMAIS ajouter de depends_on inversé ici.

resource "netbox_available_ip_address" "interfaces" {
  for_each = local.interfaces_requiring_ip

  prefix_id                    = local.networks[each.value.network_role].prefix_id
  virtual_machine_interface_id = tonumber(netbox_interface.interfaces[each.key].id)
  status                       = var.netbox_ephemeral_ip_status
  tenant_id                    = tonumber(data.netbox_tenant.this.id)

  dns_name = (
    each.value.network_role == "management" && local.global_search_domain != ""
    ? "${each.value.vm_name}.${local.global_search_domain}"
    : null
  )

  description = format(
    "%s %s/%s — %s",
    local.environment_name, each.value.vm_name, each.value.network_role, "managed-by: terraform-gitlab",
  )

  tags = local.netbox_tag_names
}

# VIP interne Kolla (kolla_internal_vip_address) : réservée dans le préfixe
# management, non rattachée à une interface (portée par keepalived/haproxy).
resource "netbox_available_ip_address" "internal_vip" {
  prefix_id = local.networks["management"].prefix_id
  status    = var.netbox_ephemeral_ip_status
  tenant_id = tonumber(data.netbox_tenant.this.id)

  dns_name = (
    local.global_search_domain != ""
    ? "${local.environment_name}-int-vip.${local.global_search_domain}"
    : null
  )

  description = "${local.environment_name} kolla_internal_vip_address — managed-by: terraform-gitlab"
  tags        = local.netbox_tag_names
}

# IP primaire de chaque VM NetBox = IP management. La ressource dépend de la
# VM et de l'IP : elle est détruite avant elles au teardown (simple
# désassociation côté NetBox).
resource "netbox_primary_ip" "nodes" {
  for_each = local.virtual_machines

  virtual_machine_id = tonumber(netbox_virtual_machine.nodes[each.key].id)
  ip_address_id      = tonumber(netbox_available_ip_address.interfaces["${each.key}/management"].id)
}
