data "openstack_images_image_v2" "this" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "this" {
  name = var.flavor_name
}

# A key is created when a public key is supplied, otherwise an existing
# keypair of the same name is reused. That keeps `terraform apply` idempotent
# across pipelines that only hold the private half of the key.
resource "openstack_compute_keypair_v2" "this" {
  count = var.ssh_public_key == "" ? 0 : 1

  name       = "${var.name_prefix}-key"
  public_key = var.ssh_public_key
}

data "openstack_compute_keypair_v2" "existing" {
  count = var.ssh_public_key == "" ? 1 : 0

  name = "${var.name_prefix}-key"
}

locals {
  keypair_name = var.ssh_public_key == "" ? one(data.openstack_compute_keypair_v2.existing[*].name) : one(openstack_compute_keypair_v2.this[*].name)

  instance_names = [
    for i in range(var.instance_count) : format("%s-web-%02d", var.name_prefix, i + 1)
  ]

  floating_ip_count = var.assign_floating_ips ? var.instance_count : 0
  data_volume_count = var.data_volume_size > 0 ? var.instance_count : 0
}

resource "openstack_networking_port_v2" "this" {
  count = var.instance_count

  name               = "${local.instance_names[count.index]}-port"
  network_id         = var.network_id
  admin_state_up     = true
  security_group_ids = var.security_group_ids
  tags               = var.tags

  fixed_ip {
    subnet_id = var.subnet_id
  }
}

resource "openstack_compute_instance_v2" "this" {
  count = var.instance_count

  name              = local.instance_names[count.index]
  image_id          = data.openstack_images_image_v2.this.id
  flavor_id         = data.openstack_compute_flavor_v2.this.id
  key_pair          = local.keypair_name
  availability_zone = var.availability_zone == "" ? null : var.availability_zone
  tags              = var.tags

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    hostname    = local.instance_names[count.index]
    environment = var.environment
    index       = count.index + 1
  })

  network {
    port = openstack_networking_port_v2.this[count.index].id
  }

  lifecycle {
    # Rebuilding every instance because the image was refreshed upstream is
    # a deliberate action, not a side effect of a plan.
    ignore_changes = [image_id]
  }
}

resource "openstack_networking_floatingip_v2" "this" {
  count = local.floating_ip_count

  pool        = var.external_network_name
  description = "Floating IP of ${local.instance_names[count.index]}"
  tags        = var.tags
}

resource "openstack_networking_floatingip_associate_v2" "this" {
  count = local.floating_ip_count

  floating_ip = openstack_networking_floatingip_v2.this[count.index].address
  port_id     = openstack_networking_port_v2.this[count.index].id
}

resource "openstack_blockstorage_volume_v3" "data" {
  count = local.data_volume_count

  name        = "${local.instance_names[count.index]}-data"
  description = "Data volume of ${local.instance_names[count.index]}"
  size        = var.data_volume_size
}

resource "openstack_compute_volume_attach_v2" "data" {
  count = local.data_volume_count

  instance_id = openstack_compute_instance_v2.this[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.data[count.index].id
}
