# generate machine secrets
resource "talos_machine_secrets" "this" {}

# generate machine configuration where the load balancer is the endpoint
data "talos_machine_configuration" "control_plane" {
  cluster_name     = "super-cluster"
  machine_type     = "controlplane"
  cluster_endpoint = "https://${hcloud_primary_ip.control_plane.ip_address}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [local.control_plane_config_patch]
}

data "talos_machine_configuration" "worker" {
  cluster_name     = data.talos_machine_configuration.control_plane.cluster_name
  cluster_endpoint = "https://${hcloud_primary_ip.control_plane.ip_address}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [local.worker_config_patch]
}

# apply the machine configuration to control plane
resource "talos_machine_configuration_apply" "control_plane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = hcloud_server.control_plane.ipv4_address
}

# bootstrap the control plane node
resource "talos_machine_bootstrap" "control_plane" {
  node                 = hcloud_server.control_plane.ipv4_address
  endpoint             = hcloud_server.control_plane.ipv4_address
  client_configuration = talos_machine_secrets.this.client_configuration

  lifecycle {
    replace_triggered_by = [hcloud_server.control_plane]
  }

  depends_on = [talos_machine_configuration_apply.control_plane]
}

# outputs
data "talos_client_configuration" "this" {
  cluster_name         = data.talos_machine_configuration.control_plane.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [hcloud_primary_ip.control_plane.ip_address]
}
output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.control_plane.ipv4_address
}
output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talos_worker_machine_configuration" {
  value     = data.talos_machine_configuration.worker.machine_configuration
  sensitive = true
}
