output "web_security_group_id" {
  description = "ID of the web security group."
  value       = openstack_networking_secgroup_v2.web.id
}

output "web_security_group_name" {
  description = "Name of the web security group."
  value       = openstack_networking_secgroup_v2.web.name
}
