provider "talos" {}

terraform {
  required_version = ">= 1.14"
}

module "cluster" {
  source = "git@github.com:pippi.io/talos-cluster?ref=a401732fe4c3f6b273caf84904a3110c336f94fe"

  cluster = {
    hostname = "k8s.pippi.io"
    name     = "pippi"

    nodes = {
      "node1.k8s.pippi.io" = {
        type = "controlplane"
        disk = "/dev/sda"
        interfaces = {
          end0 = {
            dhcp = false
            ipv4 = "192.168.1.11"
          }
        }
      }
      "node2.k8s.pippi.io" = {
        type = "worker"
        disk = "/dev/sda"
        interfaces = {
          end0 = {
            dhcp = false
            ipv4 = "192.168.1.12"
          }
        }
      }
      "node3.k8s.pippi.io" = {
        type = "worker"
        disk = "/dev/sda"
        interfaces = {
          end0 = {
            dhcp = false
            ipv4 = "192.168.1.13"
          }
        }
      }
    }
    default_routes = {
      "0.0.0.0/0" = "192.168.1.1"
    }
  }
}
