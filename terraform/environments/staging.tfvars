# Staging environment

project_name = "tp"
environment  = "staging"

external_network_name = "public"
subnet_cidr           = "10.30.20.0/24"
dns_nameservers       = ["1.1.1.1", "8.8.8.8"]

instance_count = 2
image_name     = "Ubuntu-22.04"
flavor_name    = "m1.small"

assign_floating_ips = true
data_volume_size    = 10

ssh_allowed_cidrs  = ["10.0.0.0/8"]
http_allowed_cidrs = ["0.0.0.0/0"]

tags = ["owner:platform", "cost-center:preprod"]
