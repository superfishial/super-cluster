resource "helm_release" "postgres_operator" {
  name             = "cloudnative-pg"
  namespace        = "postgres-system"
  create_namespace = true
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = "0.21.5"
}
