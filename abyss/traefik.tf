resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = "kube-system"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "26.0.0"

  # todo: increase UDP buffer size for QUIC on Talos https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes
  values = [<<YAML
    priorityClassName: system-cluster-critical

    # Listen on port 80 and 443 since we don't have load balancing
    hostNetwork: true
    deployment:
      kind: DaemonSet
    updateStrategy:
      rollingUpdate:
        maxUnavailable: 1
        maxSurge: null
    service:
      enabled: false

    logs:
      general:
        level: INFO
      access:
        enabled: true

    # Enable Prometheus metrics
    metrics:
      prometheus:
        # Create a dedicated metrics service for use with ServiceMonitor
        service:
          enabled: true
        serviceMonitor:
          enabled: true
          interval: 5s

    # todo: expose this safely or use grafana
    ingressRoute:
      dashboard:
        enabled: false

    # Allow Traefik to run as root so it can bind to port 80 and 443
    securityContext:
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE
      runAsUser: 0
      runAsGroup: 0
      runAsNonRoot: false
    ports:
      # HTTPS
      websecure:
        port: 443
        forwardedHeaders:
          trustedIPs: [${join(", ", [for ip in var.node_ips : "'${ip}/32'"])}]
          insecure: false
        http3:
          enabled: true
      # Redirect all HTTP traffic to HTTPS
      web:
        port: 80
        redirectTo:
          port: websecure
  YAML
  ]

  depends_on = [helm_release.cilium, kubectl_manifest.coreos_crds]
}
