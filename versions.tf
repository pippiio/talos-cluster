terraform {
  required_version = ">= 1.14"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }

    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.6"
    }
  }
}
