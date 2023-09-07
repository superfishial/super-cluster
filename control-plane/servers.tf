variable "talos_version" {
  type        = string
  description = "Talos version to use"
  default     = "v1.5.2"
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

resource "hcloud_server" "control_plane" {
  for_each = toset(["1", "2"])
  name     = "control-plane-${each.key}"
  labels = {
    type = "control-plane"
  }
  image              = data.hcloud_image.talos.id
  server_type        = "cpx11"
  location           = "fsn1"
  placement_group_id = hcloud_placement_group.control_plane.id

  user_data = data.talos_machine_configuration.control_plane.machine_configuration
}
