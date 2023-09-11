# generate machine secrets
resource "talos_machine_secrets" "this" {}

# generate machine configuration where the load balancer is the endpoint
locals {
  config_patch = yamlencode({
    machine = {
      certSANs = [
        local.control_plane_ipv4,
      ]
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
      # Allows using a HA internal control plane endpoint on CNI enabled nodes
      # at kubernetes.default.svc
      # https://www.talos.dev/v1.5/kubernetes-guides/configuration/kubeprism/
      features = {
        kubePrism = {
          enabled = true
          port    = 7445
        }
      }
      # Required for enabling metrics server
      # https://www.talos.dev/v1.5/kubernetes-guides/configuration/deploy-metrics-server/ 
      kubelet = {
        extraArgs = {
          rotate-server-certificates = true
        }
      }
    }
    # Enable the metrics server
    # https://www.talos.dev/v1.5/kubernetes-guides/configuration/deploy-metrics-server/
    cluster = {
      extraManifests = [
        "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
        "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
      ]
      # Cilium configuration
      # https://www.talos.dev/v1.5/kubernetes-guides/network/deploying-cilium/
      network = {
        cni = {
          name = "none"
        }
      }
      # We use Cilium's kube-proxy replacement
      proxy = {
        disabled = true
      }
      # Update cilium with the manifests/generate-cilium.sh script
      # TODO: Doesn't work because hetzner has a limit of 32768 chars for the cloud init
      inlineManifests = [
        {
          name     = "cilium"
          contents = file("${path.module}/manifests/cilium.yaml")
        }
      ]
    }
  })
}
data "talos_machine_configuration" "control_plane" {
  cluster_name     = "super-cluster"
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.control_plane_ipv4}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [local.config_patch]
}

data "talos_machine_configuration" "worker" {
  cluster_name     = data.talos_machine_configuration.control_plane.cluster_name
  cluster_endpoint = "https://${local.control_plane_ipv4}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [local.config_patch]
}

# apply the machine configuration to control plane
resource "talos_machine_configuration_apply" "control_plane" {
  count                       = var.control_plane_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = hcloud_server.control_plane[count.index].ipv4_address
}

# bootstrap the first control plane node which others will join to
resource "talos_machine_bootstrap" "control_plane" {
  node                 = hcloud_server.control_plane.0.ipv4_address
  endpoint             = hcloud_server.control_plane.0.ipv4_address
  client_configuration = talos_machine_secrets.this.client_configuration

  lifecycle {
    replace_triggered_by = [hcloud_server.control_plane.0]
  }

  depends_on = [talos_machine_configuration_apply.control_plane]
}

# outputs
data "talos_client_configuration" "this" {
  cluster_name         = data.talos_machine_configuration.control_plane.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [local.control_plane_ipv4]
}
output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.control_plane.0.ipv4_address
}
output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
