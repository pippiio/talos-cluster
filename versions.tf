terraform {
  required_version = ">= 1.13.3"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }
  }
}
