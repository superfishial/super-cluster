terraform {
  cloud {
    organization = "superfishial"
    workspaces {
      tags = ["neptune"]
    }
  }
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0"
    }
  }
}

variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token with read & write permissions"
  sensitive   = true
}

provider "hcloud" {
  token = var.hcloud_token
}
