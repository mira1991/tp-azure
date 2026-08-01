# Groupe de sécurité des smoke tests : ICMP + SSH depuis le réseau de test.

resource "openstack_networking_secgroup_v2" "smoke" {
  name        = "${var.environment_name}-smoke-sg"
  description = "Smoke tests (ICMP + SSH) — managed-by: terraform-gitlab"
  tenant_id   = openstack_identity_project_v3.smoke.id
}

resource "openstack_networking_secgroup_rule_v2" "smoke_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.smoke.id
  tenant_id         = openstack_identity_project_v3.smoke.id
}

resource "openstack_networking_secgroup_rule_v2" "smoke_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.smoke.id
  tenant_id         = openstack_identity_project_v3.smoke.id
}
