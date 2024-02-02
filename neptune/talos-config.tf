locals {
  control_plane_config_patch = yamlencode({
    machine = {
      certSANs = [
        hcloud_primary_ip.control_plane.ip_address,
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
      # Required for enabling metrics server
      # https://www.talos.dev/v1.6/kubernetes-guides/configuration/deploy-metrics-server/ 
      kubelet = {
        extraArgs = {
          rotate-server-certificates = true
        }
      }
    }
    cluster = {
      # Required for the metrics server
      # https://www.talos.dev/v1.6/kubernetes-guides/configuration/deploy-metrics-server/
      extraManifests = [
        "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
      ]
      # Cilium configuration
      # https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/
      network = {
        cni = {
          name = "none"
        }
      }
      # We use Cilium's kube-proxy replacement
      proxy = {
        disabled = true
      }
    }
  })

  worker_config_patch = yamlencode({
    machine = {
      install = {
        disk = "/dev/nvme0n1"
        # Resolves an issue on hetzner bare metal
        # https://github.com/siderolabs/talos/issues/7883#issuecomment-1836630848
        extraKernelArgs = ["-console=ttyS0"]
      }
      # todo: should be using UUIDs instead since these arent consistent
      disks = [
        {
          device = "/dev/nvme1n1"
          partitions = [{
            mountpoint = "/var/mnt/ssd-2"
          }]
        },
        {
          device = "/dev/sda"
          partitions = [{
            mountpoint = "/var/mnt/hdd"
          }]
        }
      ],
      network = {
        hostname = "nereid"
      }
      certSANs = [
        hcloud_primary_ip.control_plane.ip_address,
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
      # Required for enabling metrics server
      # https://www.talos.dev/v1.5/kubernetes-guides/configuration/deploy-metrics-server/ 
      kubelet = {
        extraArgs = {
          rotate-server-certificates = true
        }
        # Required by Longhorn
        extraMounts = [
          {
            destination = "/var/lib/longhorn"
            type        = "bind"
            source      = "/var/lib/longhorn"
            options     = ["bind", "rshared", "rw"]
          }
        ]
      }
    }
    cluster = {
      # Required for the metrics server
      # https://www.talos.dev/v1.5/kubernetes-guides/configuration/deploy-metrics-server/
      extraManifests = [
        "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
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
    }
  })
}
