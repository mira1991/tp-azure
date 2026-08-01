# Designate (optionnel) : zone DNS de validation.

resource "openstack_dns_zone_v2" "smoke" {
  count = var.enable_designate ? 1 : 0

  name        = var.dns_zone_name
  email       = var.dns_zone_email
  description = "Zone de smoke tests ${var.environment_name} — managed-by: terraform-gitlab"
  ttl         = 300
  type        = "PRIMARY"
}

resource "openstack_dns_recordset_v2" "smoke" {
  count = var.enable_designate ? 1 : 0

  zone_id     = openstack_dns_zone_v2.smoke[0].id
  name        = "ping.${var.dns_zone_name}"
  description = "Enregistrement de validation — managed-by: terraform-gitlab"
  ttl         = 300
  type        = "A"
  records     = [cidrhost(var.smoke_network_cidr, 10)]
}
