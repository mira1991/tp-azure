variable "name_prefix" {
  description = "Prefix applied to every resource name."
  type        = string
}

variable "environment" {
  description = "Deployment environment, passed to cloud-init."
  type        = string
}

variable "instance_count" {
  description = "Number of instances to create."
  type        = number
}

variable "image_name" {
  description = "Name of the Glance image to boot. Must match exactly one image."
  type        = string
}

variable "flavor_name" {
  description = "Name of the Nova flavor."
  type        = string
}

variable "availability_zone" {
  description = "Nova availability zone. Null lets the scheduler decide."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to register. Empty reuses the existing keypair named <name_prefix>-key."
  type        = string
}

variable "network_id" {
  description = "ID of the private network the ports are created on."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet the fixed IPs come from."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups bound to the instance ports."
  type        = list(string)
}

variable "floating_ip_pool" {
  description = "Name of the network floating IPs are allocated from."
  type        = string
}

variable "assign_floating_ips" {
  description = "Allocate and associate a floating IP per instance."
  type        = bool
}

variable "data_volume_size" {
  description = "Size in GB of the extra Cinder volume per instance. 0 disables it."
  type        = number
}

variable "tags" {
  description = "Tags applied to the compute resources."
  type        = list(string)
}
