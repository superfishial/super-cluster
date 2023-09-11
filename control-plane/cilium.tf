locals {
  kubeconfig = yamldecode(data.talos_cluster_kubeconfig.this.kubeconfig_raw)
}

provider "helm" {
  kubernetes {
    host                   = local.kubeconfig.clusters.0.cluster["server"]
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters.0.cluster["certificate-authority-data"])
    client_key             = base64decode(local.kubeconfig.users.0.user["client-key-data"])
    client_certificate     = base64decode(local.kubeconfig.users.0.user["client-certificate-data"])
  }
}

resource "helm_release" "cilium" {
  name      = "cilium"
  version   = "1.14.1"
  namespace = "kube-system"

  repository = "https://helm.cilium.io/"
  chart      = "cilium"

  values = [<<YAML
    ipam:
      mode: kubernetes
    kubeProxyReplacement: strict
    k8sServiceHost: localhost
    k8sServicePort: 7445
    securityContext:
      capabilities:
        ciliumAgent: [CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID]
        cleanCiliumState: [NET_ADMIN,SYS_ADMIN,SYS_RESOURCE]
    cgroup:
      autoMount:
        enabled: false
      hostRoot: /sys/fs/cgroup
  YAML
  ]

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  depends_on = [talos_machine_bootstrap.control_plane]
}
