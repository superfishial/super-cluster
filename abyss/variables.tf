variable "node_count" {
  type        = number
  description = "Number of worker nodes in the cluster"
  default     = 2
}
variable "node_ips" {
  type        = set(string)
  description = "List of IP addresses of the worker nodes"
}

variable "argocd_github_app_id" {
  type = string
}
variable "argocd_github_app_installations" {
  type        = map(string)
  description = "Installation ID as the value and organization as the key where the GitHub App is installed"
}
variable "argocd_github_app_private_key" {
  type      = string
  sensitive = true
}
variable "argocd_openid_client_id" {
  type = string
}
variable "argocd_openid_client_secret" {
  type      = string
  sensitive = true
}

variable "b2_application_key" {
  type        = string
  description = "Backblaze B2 application key"
  sensitive   = true
}
variable "b2_application_key_id" {
  type        = string
  description = "Backblaze B2 application key ID"
  sensitive   = true
}

variable "kubernetes_host" {
  type = string
}
variable "kubernetes_cluster_ca_certificate" {
  type        = string
  description = "Base64 encoded"
  sensitive   = true
}
variable "kubernetes_client_key" {
  type        = string
  description = "Base64 encoded"
  sensitive   = true
}
variable "kubernetes_client_certificate" {
  type        = string
  description = "Base64 encoded"
  sensitive   = true
}

variable "cloudflare_account_id" {
  type = string
}
variable "cloudflare_zone_ids" {
  type = set(string)
}
variable "cloudflare_token" {
  type        = string
  description = "Cloudflare API token with Zone -> DNS -> Edit, User -> API Tokens -> Edit"
  sensitive   = true
}

