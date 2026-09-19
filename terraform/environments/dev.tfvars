# Development environment
# Credentials are NOT stored here, they come from TF_VAR_* CI variables.

project_name = "tp"
environment  = "dev"

external_network_name = "public"
subnet_cidr           = "10.30.10.0/24"
dns_nameservers       = ["1.1.1.1", "8.8.8.8"]

instance_count = 1
image_name     = "Ubuntu-22.04"
flavor_name    = "m1.small"

assign_floating_ips = true
data_volume_size    = 0

ssh_allowed_cidrs  = ["0.0.0.0/0"]
http_allowed_cidrs = ["0.0.0.0/0"]

tags = ["owner:platform", "cost-center:lab"]
