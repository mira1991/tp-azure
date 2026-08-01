# Stockage : type de volume et quotas du projet de smoke tests.

resource "openstack_blockstorage_volume_type_v3" "standard" {
  name        = "${var.environment_name}-standard"
  description = "Type de volume de test — managed-by: terraform-gitlab"
  is_public   = true
}

resource "openstack_compute_quotaset_v2" "smoke" {
  project_id = openstack_identity_project_v3.smoke.id
  instances  = var.smoke_quotas.instances
  cores      = var.smoke_quotas.cores
  ram        = var.smoke_quotas.ram_mb
}

resource "openstack_blockstorage_quotaset_v3" "smoke" {
  project_id = openstack_identity_project_v3.smoke.id
  volumes    = var.smoke_quotas.volumes
  gigabytes  = var.smoke_quotas.gigabytes
  snapshots  = var.smoke_quotas.snapshots
}

resource "openstack_networking_quota_v2" "smoke" {
  project_id          = openstack_identity_project_v3.smoke.id
  network             = var.smoke_quotas.networks
  subnet              = var.smoke_quotas.subnets
  router              = var.smoke_quotas.routers
  port                = var.smoke_quotas.ports
  floatingip          = var.smoke_quotas.floatingips
  security_group      = var.smoke_quotas.secgroups
  security_group_rule = var.smoke_quotas.secgroup_rule
}
