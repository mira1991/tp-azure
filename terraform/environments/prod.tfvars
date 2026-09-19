# Production environment. Only the values that differ from the defaults in
# ../variables.tf belong here.
# Narrow ssh_allowed_cidrs to the bastion or the VPN pool before applying.

environment      = "prod"
subnet_cidr      = "10.30.30.0/24"
instance_count   = 3
flavor_name      = "m1.medium"
data_volume_size = 50

ssh_allowed_cidrs = ["10.0.0.0/8"]

tags = ["cost-center:prod"]
