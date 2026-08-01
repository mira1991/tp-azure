# Outputs consommés par les smoke tests et les rapports. Aucun secret.

output "smoke_context" {
  description = "Contexte des smoke tests (IDs des ressources à exercer)."
  value = {
    project_id        = openstack_identity_project_v3.smoke.id
    project_name      = openstack_identity_project_v3.smoke.name
    network_id        = openstack_networking_network_v2.smoke.id
    subnet_id         = openstack_networking_subnet_v2.smoke.id
    router_id         = openstack_networking_router_v2.smoke.id
    security_group_id = openstack_networking_secgroup_v2.smoke.id
    image_id          = openstack_images_image_v2.cirros.id
    image_name        = openstack_images_image_v2.cirros.name
    flavor_names      = keys(var.flavors)
    volume_type       = openstack_blockstorage_volume_type_v3.standard.name
    external_network  = var.create_external_network ? openstack_networking_network_v2.external[0].name : ""
  }
}

output "resource_ids" {
  description = "Identifiants pour le rapport de teardown et la détection d'orphelins."
  value = {
    project          = openstack_identity_project_v3.smoke.id
    user             = openstack_identity_user_v3.smoke.id
    role             = openstack_identity_role_v3.observer.id
    flavors          = { for name, flavor in openstack_compute_flavor_v2.flavors : name => flavor.id }
    image            = openstack_images_image_v2.cirros.id
    address_scope    = openstack_networking_addressscope_v2.smoke.id
    subnet_pool      = openstack_networking_subnetpool_v2.smoke.id
    external_network = var.create_external_network ? openstack_networking_network_v2.external[0].id : ""
    smoke_network    = openstack_networking_network_v2.smoke.id
    volume_type      = openstack_blockstorage_volume_type_v3.standard.id
    dns_zone         = var.enable_designate ? openstack_dns_zone_v2.smoke[0].id : ""
    load_balancer    = var.enable_octavia ? openstack_lb_loadbalancer_v2.smoke[0].id : ""
  }
}
