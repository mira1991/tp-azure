# Staging environment. Only the values that differ from the defaults in
# ../variables.tf belong here.

environment      = "staging"
subnet_cidr      = "10.30.20.0/24"
instance_count   = 2
data_volume_size = 10

ssh_allowed_cidrs = ["10.0.0.0/8"]

tags = ["cost-center:preprod"]
