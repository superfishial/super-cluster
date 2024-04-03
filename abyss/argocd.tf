resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.53.12"

  # todo: switch to github oauth
  values = [<<YAML
    global:
      networkPolicy:
        enabled: true
        defaultDenyIngress: true

    configs:
      params:
        server.insecure: true
      cm:
        url: https://cd.super.fish
        admin.enabled: false
        # Controls which people are allowed to login
        dex.config: |
          connectors:
          - type: github
            id: github
            name: GitHub
            config:
              clientID: ${var.argocd_openid_client_id}
              clientSecret: $oidc:github.clientSecret
              redirectURI: https://cd.super.fish/dex/callback
              loadAllGroups: true
              orgs:
                - name: superfishial
                  teams:
                    - superlodons
              scopes:
                - email
                - profile
                - groups
              teamNameField: slug
              useLoginAsID: true
      # Controls what permissions users get once they login
      rbac:
        policy.default: "role:admin"
        scopes: "[orgs, repos]"

    redis-ha:
      enabled: true
      hardAntiAffinity: false
      haproxy:
        enabled: true
        hardAntiAffinity: false
    controller:
      replicas: 2
      resources:
        requests:
          cpu: 250m
          memory: 256Mi
        limits:
          cpu: '2'
          memory: 2Gi
    server:
      replicas: 2
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 500m
          memory: 256Mi
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
      ingress:
        enabled: true
        hosts:
          - cd.super.fish
        annotations:
          kubernetes.io/tls-acme: "true"
        tls:
          - hosts:
            - cd.super.fish
            secretName: cd.super.fish
    repoServer:
      replicas: 2
      extraArgs:
        - --parallelismlimit=8
      resources:
        requests:
          cpu: 25m
          memory: 128Mi
        limits:
          cpu: '1'
          memory: 1Gi
    applicationSet:
      replicaCount: 2
      resources:
        requests:
          cpu: 10m
          memory: 96Mi
        limits:
          cpu: 100m
          memory: 256Mi
  YAML
  ]
  depends_on = [helm_release.longhorn, kubectl_manifest.coreos_crds]
}

resource "kubernetes_secret" "argocd_repo_creds" {
  for_each = var.argocd_github_app_installations
  metadata {
    name      = "org-repo-creds-${lower(each.key)}"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" : "repo-creds"
    }
  }
  data = {
    type                    = "git"
    url                     = "https://github.com/${each.key}"
    githubAppID             = var.argocd_github_app_id
    githubAppInstallationID = each.value
    githubAppPrivateKey     = var.argocd_github_app_private_key
  }
}

resource "kubernetes_secret" "argocd_oidc" {
  metadata {
    name      = "oidc"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels    = { "app.kubernetes.io/part-of" : "argocd" }
  }
  data = { "github.clientSecret" : var.argocd_openid_client_secret }
}
