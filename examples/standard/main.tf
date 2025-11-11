terraform {
  required_version = ">= 1.13"
}

provider "talos" {}

module "cluster" {
  source = "git@github.com:pippi.io/talos-cluster?ref=v0.1.0"

  cluster = {
    hostname      = "k8s.pippi.io"
    name          = "pippi"
    talos_version = "v1.11.3"

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
