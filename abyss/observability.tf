resource "kubectl_manifest" "coreos_crds" {
  for_each  = toset(["podmonitors", "probes", "servicemonitors"])
  yaml_body = file("${path.module}/crds/monitoring.coreos.com_${each.key}.yaml")
}

resource "kubectl_manifest" "grafana_crds" {
  for_each          = toset(["grafanaagents", "integrations", "logsinstances", "metricsinstances", "podlogs"])
  yaml_body         = file("${path.module}/crds/monitoring.grafana.com_${each.key}.yaml")
  server_side_apply = true
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = "3.11.0"

  values = [<<YAML
    replicas: 1
    podDisruptionBudget:
      enabled: true
      minAvailable: 1
    
    metrics:
      enabled: true
    
    resources:
      requests:
        cpu: 40m
        memory: 100Mi
      limits:
        cpu: 100m
        memory: 200Mi
  YAML
  ]

  depends_on = [kubectl_manifest.coreos_crds]
}
