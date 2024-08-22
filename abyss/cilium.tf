resource "helm_release" "cilium" {
  name      = "cilium"
  version   = "1.15.6"
  namespace = "kube-system"

  repository = "https://helm.cilium.io/"
  chart      = "cilium"

  values = [<<YAML
    ipam:
      mode: kubernetes
    kubeProxyReplacement: "true"
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
}
