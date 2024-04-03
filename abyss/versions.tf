terraform {
  cloud {
    organization = "superfishial"
    workspaces {
      tags = ["abyss", "cluster"]
    }
  }
  required_providers {
    b2 = {
      source  = "backblaze/b2"
      version = "~> 0.8"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }
}

provider "b2" {
  application_key_id = var.b2_application_key_id
  application_key    = var.b2_application_key
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

provider "helm" {
  kubernetes {
    host                   = var.kubernetes_host
    cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
    client_key             = base64decode(var.kubernetes_client_key)
    client_certificate     = base64decode(var.kubernetes_client_certificate)
  }
}

provider "kubernetes" {
  host                   = var.kubernetes_host
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  client_key             = base64decode(var.kubernetes_client_key)
  client_certificate     = base64decode(var.kubernetes_client_certificate)
}

provider "kubectl" {
  host                   = var.kubernetes_host
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  client_key             = base64decode(var.kubernetes_client_key)
  client_certificate     = base64decode(var.kubernetes_client_certificate)
  load_config_file       = false
}
