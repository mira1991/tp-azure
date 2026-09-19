resource "openstack_networking_secgroup_v2" "web" {
  name                 = "${var.name_prefix}-web"
  description          = "Web tier of ${var.name_prefix}, managed by Terraform"
  delete_default_rules = true
  tags                 = var.tags
}

# Egress is open: instances need to reach package mirrors and the metadata API.
resource "openstack_networking_secgroup_rule_v2" "egress_ipv4" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "egress"
  ethertype         = "IPv4"
  description       = "Allow all outbound IPv4 traffic"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  for_each = toset(var.ssh_allowed_cidrs)

  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
  description       = "SSH from ${each.value}"
}

resource "openstack_networking_secgroup_rule_v2" "web" {
  # One rule per (public listener, allowed source) pair.
  for_each = {
    for pair in setproduct([80, 443], var.http_allowed_cidrs) :
    "${pair[0]}-${pair[1]}" => {
      port = pair[0]
      cidr = pair[1]
    }
  }

  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
  description       = "TCP/${each.value.port} from ${each.value.cidr}"
}

# ICMP and full east-west traffic inside the tenant subnet.
resource "openstack_networking_secgroup_rule_v2" "icmp_internal" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.subnet_cidr
  description       = "ICMP inside the tenant subnet"
}

resource "openstack_networking_secgroup_rule_v2" "internal" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.web.id
  description       = "Allow members of the group to talk to each other"
}
