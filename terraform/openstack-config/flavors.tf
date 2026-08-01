# Flavors de test.

resource "openstack_compute_flavor_v2" "flavors" {
  for_each = var.flavors

  name      = each.key
  vcpus     = each.value.vcpus
  ram       = each.value.ram_mb
  disk      = each.value.disk_gb
  is_public = each.value.is_public

  extra_specs = {
    "hw_rng:allowed" = "true"
  }
}
