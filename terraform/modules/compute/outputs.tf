output "instance_ids" {
  description = "IDs of the created instances."
  value       = openstack_compute_instance_v2.this[*].id
}

output "private_ips" {
  description = "Fixed IP addresses on the private subnet."
  value       = openstack_networking_port_v2.this[*].all_fixed_ips[0]
}

output "floating_ips" {
  description = "Floating IP addresses, empty when assign_floating_ips is false."
  value       = openstack_networking_floatingip_v2.this[*].address
}
