# Réseaux : address scope, subnet pool, réseau provider externe, réseau
# self-service de smoke tests, routeur.

resource "openstack_networking_addressscope_v2" "smoke" {
  name       = "${var.environment_name}-scope"
  ip_version = 4
  shared     = false
}

resource "openstack_networking_subnetpool_v2" "smoke" {
  name              = "${var.environment_name}-pool"
  prefixes          = var.subnet_pool_prefixes
  address_scope_id  = openstack_networking_addressscope_v2.smoke.id
  default_prefixlen = 24
  min_prefixlen     = 20
  max_prefixlen     = 28
}

# ---------------------------------------------------------------------------
# Réseau provider externe (floating IPs)
# ---------------------------------------------------------------------------

resource "openstack_networking_network_v2" "external" {
  count = var.create_external_network ? 1 : 0

  name                  = "${var.environment_name}-external"
  external              = true
  shared                = false
  admin_state_up        = true
  port_security_enabled = true

  segments {
    network_type     = var.provider_network_type
    physical_network = var.provider_physical_network
    segmentation_id  = var.provider_network_type == "vlan" ? var.provider_segmentation_id : null
  }

  lifecycle {
    precondition {
      condition     = var.provider_network_type != "vlan" || var.provider_segmentation_id != null
      error_message = "provider_segmentation_id est requis quand provider_network_type = vlan."
    }
  }
}

resource "openstack_networking_subnet_v2" "external" {
  count = var.create_external_network ? 1 : 0

  name        = "${var.environment_name}-external-subnet"
  network_id  = openstack_networking_network_v2.external[0].id
  cidr        = var.external_cidr
  ip_version  = 4
  enable_dhcp = false
  gateway_ip  = var.external_gateway_ip != "" ? var.external_gateway_ip : cidrhost(var.external_cidr, 1)

  allocation_pool {
    start = var.external_pool_start
    end   = var.external_pool_end
  }
}

# ---------------------------------------------------------------------------
# Réseau self-service de smoke tests
# ---------------------------------------------------------------------------

resource "openstack_networking_network_v2" "smoke" {
  name           = "${var.environment_name}-smoke-net"
  tenant_id      = openstack_identity_project_v3.smoke.id
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "smoke" {
  name            = "${var.environment_name}-smoke-subnet"
  network_id      = openstack_networking_network_v2.smoke.id
  tenant_id       = openstack_identity_project_v3.smoke.id
  cidr            = var.smoke_network_cidr
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.smoke_dns_nameservers
}

resource "openstack_networking_router_v2" "smoke" {
  name           = "${var.environment_name}-smoke-router"
  tenant_id      = openstack_identity_project_v3.smoke.id
  admin_state_up = true

  external_network_id = var.create_external_network ? openstack_networking_network_v2.external[0].id : null
}

resource "openstack_networking_router_interface_v2" "smoke" {
  router_id = openstack_networking_router_v2.smoke.id
  subnet_id = openstack_networking_subnet_v2.smoke.id
}
