provider "talos" {}

terraform {
  required_version = ">= 1.14"
}

module "cluster" {
  source = "git@github.com:pippi.io/talos-cluster?ref=a401732fe4c3f6b273caf84904a3110c336f94fe"

  cluster = {
    hostname = "k8s.pippi.io" # Or can be set to the VIP "192.168.1.5" if no DNS is setup
    vip      = "192.168.1.5"
    name     = "pippi"

    nodes = {
      "node1.k8s.pippi.io" = {
        type = "controlplane"
        disk = "/dev/sda"
        interfaces = {
          end0 = {
            ipv4_address_cidr = "192.168.1.11/24"
          }
        }
      }
      "node2.k8s.pippi.io" = {
        type = "worker"
        disk = "/dev/sda"
        interfaces = {
          end0 = {
            ipv4_address_cidr = "192.168.1.12/24"
          }
        }
      }
      "node3.k8s.pippi.io" = {
        type = "worker"
        disk = "/dev/disk/by-id/nvme-eui.0000000000000001234"
        interfaces = {
          end0 = {
            ipv4_address_cidr = "192.168.1.13/24"
          }
        }
      }
    }
    default_routes = {
      "0.0.0.0/0" = "192.168.1.1"
    }
    name_servers = [
      "192.168.1.1"
    ]
  }
}
