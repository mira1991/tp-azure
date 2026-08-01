# Objets VM NetBox temporaires — sommet du graphe de dépendances :
#   netbox_virtual_machine -> netbox_interface -> netbox_available_ip_address
#   -> proxmox_virtual_environment_vm
# Au destroy, Terraform inverse automatiquement cet ordre.

locals {
  netbox_permanent_tag_names = [for t in data.netbox_tag.permanent : t.name]

  # Tags appliqués à tous les objets éphémères. Les tags d'environnement et
  # de pipeline sont eux-mêmes des ressources Terraform : ils sont créés
  # avant les objets qui les portent et supprimés en dernier au destroy.
  netbox_tag_names = concat(
    local.netbox_permanent_tag_names,
    [netbox_tag.environment.name],
    var.pipeline_id == "" ? [] : [netbox_tag.pipeline[0].name],
  )

  netbox_custom_field_values = {
    environment_id   = tostring(var.environment_id)
    environment_name = local.environment_name
    pipeline_id      = var.pipeline_id
    pipeline_url     = var.pipeline_url
    project_path     = var.project_path
    owner            = var.environment_owner
    purpose          = var.environment_purpose
    expires_at       = var.expires_at
    managed_by       = "terraform-gitlab"
  }

  # Mapping nom logique -> nom réel du custom field (config/netbox-fields.yml).
  # Les champs à null et les valeurs vides sont omis.
  netbox_custom_fields = {
    for logical, actual in local.netbox_fields_config.custom_fields :
    actual => local.netbox_custom_field_values[logical]
    if actual != null && try(local.netbox_custom_field_values[logical], "") != ""
  }
}

resource "netbox_tag" "environment" {
  name        = format("environment-%d", var.environment_id)
  slug        = format("environment-%d", var.environment_id)
  color_hex   = "9e9e9e"
  description = "Environnement éphémère ${local.environment_name} (managed-by: terraform-gitlab)"
}

resource "netbox_tag" "pipeline" {
  count = var.pipeline_id == "" ? 0 : 1

  name        = format("pipeline-%s", var.pipeline_id)
  slug        = format("pipeline-%s", var.pipeline_id)
  color_hex   = "607d8b"
  description = "Pipeline GitLab ${var.pipeline_url}"
}

resource "netbox_virtual_machine" "nodes" {
  for_each = local.virtual_machines

  name        = each.key
  cluster_id  = tonumber(data.netbox_cluster.this.id)
  site_id     = var.netbox_assign_site_to_vms ? tonumber(data.netbox_site.this.id) : null
  tenant_id   = tonumber(data.netbox_tenant.this.id)
  role_id     = tonumber(data.netbox_device_role.vm_role.id)
  platform_id = tonumber(data.netbox_platform.this.id)

  vcpus        = each.value.vcpu
  memory_mb    = each.value.memory_mb
  disk_size_mb = each.value.disk_gb * 1024
  status       = "active"

  description = format(
    "Ephemeral OpenStack %s node — %s (owner: %s, expires: %s)",
    each.value.role, local.environment_name, var.environment_owner, var.expires_at,
  )

  tags          = local.netbox_tag_names
  custom_fields = local.netbox_custom_fields

  lifecycle {
    precondition {
      condition     = length(each.value.networks) > 0 && each.value.networks[0] == "management"
      error_message = "Le premier réseau du nœud '${each.key}' doit être 'management' (contrat des profils, cf. config/profiles.yml)."
    }
  }
}
