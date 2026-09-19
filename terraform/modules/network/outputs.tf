output "network_id" {
  description = "ID of the private network."
  value       = openstack_networking_network_v2.this.id
}

output "subnet_id" {
  description = "ID of the private subnet."
  value       = openstack_networking_subnet_v2.this.id

  # Consumers of the subnet (ports, and therefore instances) must wait for the
  # router interface, otherwise an instance can boot before it has a route out
  # and cloud-init cannot reach the package mirrors.
  depends_on = [openstack_networking_router_interface_v2.this]
}

output "router_id" {
  description = "ID of the router."
  value       = openstack_networking_router_v2.this.id
}

output "external_network_name" {
  description = "Name of the external network, resolved once here and reused as the floating IP pool."
  value       = data.openstack_networking_network_v2.external.name
}
