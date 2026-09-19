# Production environment
# Narrow the SSH range to the bastion or the VPN pool before applying.

project_name = "tp"
environment  = "prod"

external_network_name = "public"
subnet_cidr           = "10.30.30.0/24"
dns_nameservers       = ["1.1.1.1", "8.8.8.8"]

instance_count = 3
image_name     = "Ubuntu-22.04"
flavor_name    = "m1.medium"

assign_floating_ips = true
data_volume_size    = 50

ssh_allowed_cidrs  = ["10.0.0.0/8"]
http_allowed_cidrs = ["0.0.0.0/0"]

tags = ["owner:platform", "cost-center:prod"]
