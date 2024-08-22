resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = "kube-system"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.15.1"

  values = [<<YAML
    replicaCount: 1
    installCRDs: true
    prometheus:
      servicemonitor:
        enabled: true
    # Use a default issuer
    ingressShim:
      defaultIssuerName: letsencrypt
      defaultIssuerKind: ClusterIssuer
      defaultIssuerGroup: cert-manager.io
  YAML
  ]

  depends_on = [helm_release.cilium, kubectl_manifest.coreos_crds]
}

# Self Signed Issuer
resource "kubectl_manifest" "self_signed_issuer" {
  yaml_body  = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: self-signed
    spec:
      selfSigned: {}
  YAML
  depends_on = [helm_release.cert_manager]
}

# Cloudflare Issuer
data "cloudflare_api_token_permission_groups" "cert_manager" {}
resource "cloudflare_api_token" "dns_token" {
  name = "Superfishial Cert Manager"
  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.cert_manager.zone["DNS Write"]
    ]
    resources = {
      "com.cloudflare.api.account.${var.cloudflare_account_id}" = jsonencode({
        for zone_id in var.cloudflare_zone_ids : "com.cloudflare.api.account.zone.${zone_id}" => "*"
      })
    }
  }
}

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = resource.helm_release.cert_manager.namespace
  }
  data = {
    "api-token" = cloudflare_api_token.dns_token.value
  }
}

resource "kubectl_manifest" "cloudflare_issuer" {
  yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt
      namespace: ${resource.helm_release.cert_manager.namespace}
    spec:
      acme:
        # Let's Encrypt will use this to contact you about expiring
        # certificates, and issues related to your account.
        email: superlodon@super.fish
        server: https://acme-v02.api.letsencrypt.org/directory
        # Secret resource that will be used to store the account's private key
        privateKeySecretRef:
          name: letsencrypt-issuer-account-key
        # A DNS challenge solver using cloudflare API
        solvers:
        - dns01:
            cloudflare:
              apiTokenSecretRef:
                name: ${kubernetes_secret.cloudflare_api_token.metadata[0].name}
                key: api-token
  YAML

  depends_on = [helm_release.cert_manager]
}
