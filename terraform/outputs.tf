output "network_id" {
  description = "ID of the private tenant network."
  value       = module.network.network_id
}

output "subnet_id" {
  description = "ID of the private tenant subnet."
  value       = module.network.subnet_id
}

output "router_id" {
  description = "ID of the router connected to the external network."
  value       = module.network.router_id
}

output "security_group_id" {
  description = "ID of the security group attached to the web instances."
  value       = module.security.web_security_group_id
}

output "instance_ids" {
  description = "IDs of the created instances."
  value       = module.compute.instance_ids
}

output "instance_private_ips" {
  description = "Fixed IP addresses of the instances on the private subnet."
  value       = module.compute.private_ips
}

output "instance_floating_ips" {
  description = "Floating IP addresses of the instances, empty when assign_floating_ips is false."
  value       = module.compute.floating_ips
}

output "ssh_commands" {
  description = "Ready to paste SSH commands for the reachable instances."
  value       = module.compute.ssh_commands
}
