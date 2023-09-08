# generate machine secrets
resource "talos_machine_secrets" "this" {}

# generate machine configuration where the load balancer is the endpoint
data "talos_machine_configuration" "control_plane" {
  cluster_name     = "super-cluster"
  machine_type     = "controlplane"
  cluster_endpoint = "https://${hcloud_load_balancer.control_plane.ipv4}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [
    yamlencode({
      machine = {
        certSANs = [
          hcloud_load_balancer.control_plane.ipv4
        ],
        time = {
          servers = [
            "ntp1.hetzner.de",
            "ntp2.hetzner.com",
            "ntp3.hetzner.net",
            "0.de.pool.ntp.org",
            "1.de.pool.ntp.org",
            "time.cloudflare.com"
          ]
        }
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name     = data.talos_machine_configuration.control_plane.cluster_name
  cluster_endpoint = "https://${hcloud_load_balancer.control_plane.ipv4}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [
    yamlencode({
      machine = {
        certSANs = [
          hcloud_load_balancer.control_plane.ipv4
        ],
        time = {
          servers = [
            "ntp1.hetzner.de",
            "ntp2.hetzner.com",
            "ntp3.hetzner.net",
            "0.de.pool.ntp.org",
            "1.de.pool.ntp.org",
            "time.cloudflare.com"
          ]
        }
      }
    })
  ]
}

# apply the machine configuration to control plane
resource "talos_machine_configuration_apply" "control_plane" {
  for_each                    = hcloud_server.control_plane
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = each.value.ipv4_address
}

# bootstrap the first control plane node which others will join to
resource "talos_machine_bootstrap" "control_plane" {
  node                 = hcloud_server.control_plane.1.ipv4_address
  endpoint             = hcloud_server.control_plane.1.ipv4_address
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_machine_configuration_apply.control_plane]
}

# outputs
data "talos_client_configuration" "this" {
  cluster_name         = data.talos_machine_configuration.control_plane.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [hcloud_load_balancer.control_plane.ipv4]
}
output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.control_plane.1.ipv4_address
}
output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
