locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = concat(
    [
      "project:${var.project_name}",
      "environment:${var.environment}",
      "managed-by:terraform",
    ],
    var.tags,
  )
}

module "network" {
  source = "./modules/network"

  name_prefix           = local.name_prefix
  external_network_name = var.external_network_name
  subnet_cidr           = var.subnet_cidr
  dns_nameservers       = var.dns_nameservers
  tags                  = local.common_tags
}

module "security" {
  source = "./modules/security"

  name_prefix        = local.name_prefix
  subnet_cidr        = var.subnet_cidr
  ssh_allowed_cidrs  = var.ssh_allowed_cidrs
  http_allowed_cidrs = var.http_allowed_cidrs
  tags               = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  name_prefix           = local.name_prefix
  environment           = var.environment
  instance_count        = var.instance_count
  image_name            = var.image_name
  flavor_name           = var.flavor_name
  availability_zone     = var.availability_zone
  ssh_public_key        = var.ssh_public_key
  data_volume_size      = var.data_volume_size
  assign_floating_ips   = var.assign_floating_ips
  external_network_name = var.external_network_name
  network_id            = module.network.network_id
  subnet_id             = module.network.subnet_id
  security_group_ids    = [module.security.web_security_group_id]
  tags                  = local.common_tags

  # The router interface must exist before the instances boot, otherwise
  # cloud-init cannot reach the package mirrors.
  depends_on = [module.network]
}
