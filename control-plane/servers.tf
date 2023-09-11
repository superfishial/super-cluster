variable "talos_version" {
  type        = string
  description = "Talos version to use"
  default     = "v1.5.2"
}

variable "control_plane_count" {
  type        = number
  description = "Number of control plane nodes"
  default     = 1
}

data "hcloud_image" "talos" {
  with_selector = "os=talos,version=${var.talos_version}"
}

resource "hcloud_placement_group" "control_plane" {
  name = "control-plane"
  type = "spread"
  labels = {
    type = "control-plane"
  }
}

resource "hcloud_primary_ip" "control_plane" {
  count         = var.control_plane_count
  name          = "control-plane-${count.index + 1}"
  type          = "ipv4"
  datacenter    = "fsn1-dc14"
  assignee_type = "server"
  auto_delete   = false
  labels = {
    "type" = "control-plane"
  }
}

resource "hcloud_server" "control_plane" {
  count = var.control_plane_count
  name  = "control-plane-${count.index + 1}"
  labels = {
    type = "control-plane"
  }
  image              = data.hcloud_image.talos.id
  server_type        = "cpx21"
  datacenter         = hcloud_primary_ip.control_plane[count.index].datacenter
  placement_group_id = hcloud_placement_group.control_plane.id
  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.control_plane[count.index].id
    ipv6_enabled = true
  }

  user_data = data.talos_machine_configuration.control_plane.machine_configuration
}
