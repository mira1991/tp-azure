variable "name_prefix" {
  description = "Prefix applied to every resource name."
  type        = string
}

variable "external_network_name" {
  description = "Name of the external provider network the router uplinks to."
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR of the private subnet."
  type        = string
}

variable "dns_nameservers" {
  description = "DNS resolvers advertised over DHCP."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the network resources."
  type        = list(string)
}
