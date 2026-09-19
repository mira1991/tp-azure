output "network_id" {
  description = "ID of the private network."
  value       = openstack_networking_network_v2.this.id
}

output "subnet_id" {
  description = "ID of the private subnet."
  value       = openstack_networking_subnet_v2.this.id
}

output "router_id" {
  description = "ID of the router."
  value       = openstack_networking_router_v2.this.id
}

output "external_network_id" {
  description = "ID of the external network resolved by name."
  value       = data.openstack_networking_network_v2.external.id
}
