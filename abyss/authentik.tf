resource "kubernetes_namespace" "authentik" {
  metadata {
    name = "authentik"
  }
}

resource "helm_release" "authentik" {
  name       = "authentik"
  namespace  = kubernetes_namespace.authentik.metadata[0].name
  repository = "https://charts.goauthentik.io"
  chart      = "authentik"
  version    = "2024.8.5"

  set_sensitive {
    name  = "authentik.secret_key"
    value = random_password.authentik_secret_key.result
  }

  values = [<<YAML
    server:
      replicas: 2
      metrics:
        serviceMonitor:
          enabled: true
      ingress:
        enabled: true
        annotations:
          kubernetes.io/tls-acme: "true"
        hosts:
          - auth.super.fish
        tls:
          - hosts:
            - auth.super.fish
            secretName: auth.super.fish
      requests:
        cpu: 50m
        memory: 256Mi
      limits:
        cpu: '1'
        memory: 1Gi
    worker:
      replicas: 2
      requests:
        cpu: 50m
        memory: 256Mi
      limits:
        cpu: '1'
        memory: 1Gi

    authentik:
      postgresql:
        host: authentik-postgres-rw
        # Database name
        name: authentik
        username: authentik

    global:
      env:
        - name: AUTHENTIK_SECRET_KEY
          valueFrom:
            secretKeyRef:
              key: secret-key
              name: authentik-config
        - name: AUTHENTIK_POSTGRESQL__SSLMODE
          value: require
        - name: AUTHENTIK_POSTGRESQL__HOST
          value: authentik-postgres-rw
        - name: AUTHENTIK_POSTGRESQL__PORT
          value: "5432"
        - name: AUTHENTIK_POSTGRESQL__DATABASE
          value: authentik
        - name: AUTHENTIK_POSTGRESQL__USERNAME
          value: authentik
        - name: AUTHENTIK_POSTGRESQL__PASSWORD
          valueFrom:
            secretKeyRef:
              key: password
              name: ${kubernetes_secret.authentik_postgres_password.metadata[0].name}
        - name: AUTHENTIK_REDIS__PASSWORD
          valueFrom:
            secretKeyRef:
              key: redis-password
              name: authentik-config

    geoip:
      enabled: false

    redis:
      enabled: true
      architecture: standalone
      auth:
        enabled: true
        existingSecret: authentik-config
        existingSecretPasswordKey: redis-password
  YAML
  ]

  depends_on = [helm_release.longhorn, kubectl_manifest.authentik_postgres, kubectl_manifest.coreos_crds]
}

resource "random_password" "authentik_secret_key" {
  length           = 64
  special          = false
  override_special = "_-"
}

resource "random_password" "authentik_redis_password" {
  length           = 64
  special          = false
  override_special = "_-"
}

resource "kubernetes_secret" "authentik_config" {
  metadata {
    name      = "authentik-config"
    namespace = kubernetes_namespace.authentik.metadata[0].name
  }
  data = {
    "secret-key"     = random_password.authentik_secret_key.result
    "redis-password" = random_password.authentik_redis_password.result
  }
}

# Postgres
resource "random_password" "authentik_postgres_password" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "authentik_postgres_password" {
  metadata {
    name      = "authentik-postgres-password"
    namespace = kubernetes_namespace.authentik.metadata[0].name
  }
  data = {
    "username" = "authentik"
    "password" = random_password.authentik_postgres_password.result
  }
}

resource "kubectl_manifest" "authentik_postgres" {
  yaml_body = <<YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: authentik-postgres
      namespace: ${kubernetes_namespace.authentik.metadata[0].name}
    spec:
      instances: 2
      bootstrap:
        initdb:
          database: authentik
          owner: authentik
          secret:
            name: ${kubernetes_secret.authentik_postgres_password.metadata[0].name}
      storage:
        size: 10Gi
  YAML

  depends_on = [helm_release.postgres_operator]
}
