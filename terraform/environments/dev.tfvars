# Development environment. Only the values that differ from the defaults in
# ../variables.tf belong here. Credentials come from TF_VAR_* CI variables.

environment    = "dev"
subnet_cidr    = "10.30.10.0/24"
instance_count = 1

tags = ["cost-center:lab"]
