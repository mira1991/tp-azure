data "openstack_networking_network_v2" "external" {
  name     = var.external_network_name
  external = true
}

resource "openstack_networking_network_v2" "this" {
  name           = "${var.name_prefix}-net"
  admin_state_up = true
  tags           = var.tags
}

resource "openstack_networking_subnet_v2" "this" {
  name            = "${var.name_prefix}-subnet"
  network_id      = openstack_networking_network_v2.this.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.dns_nameservers
  tags            = var.tags
}

resource "openstack_networking_router_v2" "this" {
  name                = "${var.name_prefix}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
  tags                = var.tags
}

resource "openstack_networking_router_interface_v2" "this" {
  router_id = openstack_networking_router_v2.this.id
  subnet_id = openstack_networking_subnet_v2.this.id
}
