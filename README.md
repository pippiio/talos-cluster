<!-- BEGIN_TF_DOCS -->
# pippi.io/talos-cluster

This Terraform module automates the configuration of a Talos cluster.

# Examples

```hcl
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

      default_routes = {
        "0.0.0.0/0" = "192.168.1.1"
      }
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13.3 |
| talos | ~> 0.9 |

## Providers

| Name | Version |
|------|---------|
| talos | 0.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster | Talos cluster configurastion:<br/>      hostname: The hostname of the talos kubernetes cluster<br/>      name: The name of the talos kubernetes cluster<br/>      talos\_version:<br/>      nodes: A map<br/>        key: The nodes hostname<br/>        value:<br/>          type: Type of the node. Valid values includes [controlplane,worker]<br/>          disk: The Talos install disk.<br/>          interfaces:<br/>            key: interface id<br/>            value:<br/>              dhcp: true to enable dhcp<br/>              ipv4: ipv4 address<br/>      default\_routes: A map of network routes<br/>        key: network CIDR<br/>        value: Gateway IP | <pre>object({<br/>    hostname      = string<br/>    name          = string<br/>    talos_version = string<br/><br/>    nodes = map(object({<br/>      type = string<br/>      disk = string<br/><br/>      interfaces = map(object({<br/>        dhcp   = bool<br/>        ipv4   = optional(string)<br/>        routes = optional(map(string))<br/>      }))<br/>    }))<br/><br/>    default_routes = optional(map(string), {})<br/>  })</pre> | n/a | yes |



## Resources

| Name | Type |
|------|------|
| [talos_cluster_kubeconfig.kubeconfig](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/cluster_health) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Outputs

| Name | Description |
|------|-------------|
| kubeconfig | The Talos cluster kubeconfig |
| talosconfig | The Talos cluster talosconfig |

<!-- END_TF_DOCS -->