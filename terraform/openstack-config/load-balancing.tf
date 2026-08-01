# Octavia (optionnel) : chaîne complète LB -> listener -> pool -> monitor
# sur le réseau de smoke tests.

resource "openstack_lb_loadbalancer_v2" "smoke" {
  count = var.enable_octavia ? 1 : 0

  name          = "${var.environment_name}-smoke-lb"
  description   = "Load balancer de validation Octavia — managed-by: terraform-gitlab"
  vip_subnet_id = openstack_networking_subnet_v2.smoke.id
}

resource "openstack_lb_listener_v2" "smoke" {
  count = var.enable_octavia ? 1 : 0

  name            = "${var.environment_name}-smoke-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.smoke[0].id
}

resource "openstack_lb_pool_v2" "smoke" {
  count = var.enable_octavia ? 1 : 0

  name        = "${var.environment_name}-smoke-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.smoke[0].id
}

resource "openstack_lb_monitor_v2" "smoke" {
  count = var.enable_octavia ? 1 : 0

  name        = "${var.environment_name}-smoke-monitor"
  pool_id     = openstack_lb_pool_v2.smoke[0].id
  type        = "HTTP"
  delay       = 10
  timeout     = 5
  max_retries = 3
}

# Barbican (optionnel) : secret de validation au payload non sensible —
# aucun secret réel n'est stocké dans le state.
resource "openstack_keymanager_secret_v1" "smoke" {
  count = var.enable_barbican ? 1 : 0

  name                 = "${var.environment_name}-smoke-secret"
  payload              = "eph-smoke-validation"
  payload_content_type = "text/plain"
  secret_type          = "opaque"
}
