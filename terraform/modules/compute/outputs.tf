output "instance_ids" {
  description = "IDs of the created instances."
  value       = openstack_compute_instance_v2.this[*].id
}

output "instance_names" {
  description = "Names of the created instances."
  value       = openstack_compute_instance_v2.this[*].name
}

output "private_ips" {
  description = "Fixed IP addresses on the private subnet."
  value       = openstack_networking_port_v2.this[*].all_fixed_ips[0]
}

output "floating_ips" {
  description = "Floating IP addresses, empty when assign_floating_ips is false."
  value       = openstack_networking_floatingip_v2.this[*].address
}

output "keypair_name" {
  description = "Name of the keypair injected into the instances."
  value       = local.keypair_name
}

output "ssh_commands" {
  description = "SSH commands for the instances that carry a floating IP."
  value = [
    for ip in openstack_networking_floatingip_v2.this[*].address : "ssh ubuntu@${ip}"
  ]
}
