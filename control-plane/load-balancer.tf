locals {
  control_plane_ipv4 = var.control_plane_count > 1 ? hcloud_load_balancer.control_plane.0.ipv4 : hcloud_primary_ip.control_plane.0.ip_address
}

# load balancer in front of the nodes
resource "hcloud_load_balancer" "control_plane" {
  count = var.control_plane_count > 1 ? 1 : 0
  name  = "control-plane"
  labels = {
    type = "control-plane"
  }
  load_balancer_type = "lb11"
  location           = "fsn1"
}

# add nodes
resource "hcloud_load_balancer_target" "load_balancer_target" {
  count            = var.control_plane_count > 1 ? var.control_plane_count : 0
  type             = "server"
  load_balancer_id = hcloud_load_balancer.control_plane.0.id
  server_id        = hcloud_server.control_plane[count.index].id
}

# control plane service
resource "hcloud_load_balancer_service" "load_balancer_service" {
  count            = var.control_plane_count > 1 ? 1 : 0
  load_balancer_id = hcloud_load_balancer.control_plane.0.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443
}
# talos CTL service
resource "hcloud_load_balancer_service" "talosctl_service" {
  count            = var.control_plane_count > 1 ? 1 : 0
  load_balancer_id = hcloud_load_balancer.control_plane.0.id
  protocol         = "tcp"
  listen_port      = 50000
  destination_port = 50000
}
