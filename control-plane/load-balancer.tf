# load balancer in front of the nodes
resource "hcloud_load_balancer" "control_plane" {
  name = "control-plane"
  labels = {
    type = "control-plane"
  }
  load_balancer_type = "lb11"
  location           = "fsn1"
}

# add nodes
resource "hcloud_load_balancer_target" "load_balancer_target" {
  for_each         = hcloud_server.control_plane
  type             = "server"
  load_balancer_id = hcloud_load_balancer.control_plane.id
  server_id        = each.value.id
}

# control plane service
resource "hcloud_load_balancer_service" "load_balancer_service" {
  load_balancer_id = hcloud_load_balancer.control_plane.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443
}
# talos CTL service
resource "hcloud_load_balancer_service" "talosctl_service" {
  load_balancer_id = hcloud_load_balancer.control_plane.id
  protocol         = "tcp"
  listen_port      = 50000
  destination_port = 50000
}
