variable "name_prefix" {
  description = "Prefix applied to every resource name."
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR of the private subnet, used for the east-west rules."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "Source ranges allowed to reach TCP/22."
  type        = list(string)
}

variable "http_allowed_cidrs" {
  description = "Source ranges allowed to reach TCP/80 and TCP/443."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the security group."
  type        = list(string)
  default     = []
}
