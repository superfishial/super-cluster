resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  namespace  = "kube-system"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = "2.14.2"

  values = [<<YAML
    # CLI expects the controller to have this name
    fullnameOverride: sealed-secrets-controller
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
    networkPolicy:
      enabled: true
    metrics:
      serviceMonitor:
        enabled: true
  YAML
  ]

  depends_on = [helm_release.cilium, kubectl_manifest.coreos_crds]
}
