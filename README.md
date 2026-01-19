<!-- BEGIN_TF_DOCS -->
# pippi.io/talos-cluster

This Terraform module automates the configuration of a Talos cluster.

# Examples

```hcl
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
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.14 |
| dns | ~> 3.4 |
| local | ~> 2.6 |
| talos | ~> 0.9 |

## Providers

| Name | Version |
|------|---------|
| dns | ~> 3.4 |
| local | ~> 2.6 |
| talos | ~> 0.9 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster | Talos cluster configurastion:<br/>      hostname: The hostname of the talos kubernetes cluster<br/>      name: The name of the talos kubernetes cluster<br/>      disk\_selector: CEL expression to filter disks in output<br/>      nodes: A map<br/>        key: The nodes hostname<br/>        value:<br/>          type: Type of the node. Valid values includes [controlplane,worker]<br/>          install\_disk: The Talos install disk.<br/>          disks: Node disk configuration:<br/>            key: device<br/>            value: mounitpoint<br/>          interfaces:<br/>            key: interface id<br/>            value:<br/>              dhcp: true to enable dhcp<br/>              ipv4: ipv4 address<br/>              routes: A map of routes structured <network-cidr>=<gateway-ip><br/>      time\_servers: A set of NTP time server hostnames used for nodes<br/>      default\_routes: A map of default routes structured <network-cidr>=<gateway-ip> | <pre>object({<br/>    hostname      = string<br/>    name          = string<br/>    disk_selector = optional(string, "disk.size > 50u * GB && disk.readonly == false")<br/>    nodes = map(object({<br/>      type         = string<br/>      install_disk = string<br/>      disks        = optional(map(string), {})<br/>      image        = optional(string)<br/>      hostname     = optional(string) # defaults to key<br/>      interfaces = map(object({<br/>        dhcp        = bool<br/>        ipv4        = optional(string)<br/>        cidr_prefix = optional(string, "24")<br/>        routes      = optional(map(string))<br/>        mtu         = optional(number)<br/>        bond = optional(object({<br/>          mode             = optional(string, "active+backup")<br/>          miimon           = optional(number, 100)<br/>          lacp_rate        = optional(string)<br/>          xmit_hash_policy = optional(string)<br/>          interfaces       = list(string)<br/>        }))<br/>      }))<br/>      temporary_ip = optional(string)<br/>    }))<br/><br/>    encryption = optional(object({<br/>      enabled    = bool<br/>      node_id    = optional(bool, false)<br/>      passphrase = optional(string)<br/>      }), {<br/>      enabled = true<br/>      node_id = true<br/>    })<br/>    virtual_ip            = optional(string)<br/>    image                 = optional(string)<br/>    nameservers           = optional(list(string), [])<br/>    time_servers          = optional(set(string), [])<br/>    default_routes        = optional(map(string), {})<br/>    kubeadm_cert_lifetime = optional(string, "12h0m0s")<br/>  })</pre> | n/a | yes |
| configfile | Local config file configuration. NB! files contains sensitive certificates:<br/>      talosconfig: Talos config file:<br/>        save\_to\_disk: True if talosconfig is saved to local file.<br/>        path: File path. Defaults to ~/.talos/config<br/>        owerwrite: True if existing file is owerwritten. False will merge with existing file.<br/>      kubeconfig: Kube config file:<br/>        save\_to\_disk: True if kubeconfig is saved to local file.<br/>        path: File path. Defaults to ~/.kube/config<br/>        owerwrite: True if existing file is owerwritten. False will merge with existing file. | <pre>object({<br/>    talosconfig = optional(object({<br/>      save_to_disk = optional(bool, false)<br/>      path         = optional(string, "~/.talos/config")<br/>      owerwrite    = optional(bool, false)<br/>    }), {})<br/>    kubeconfig = optional(object({<br/>      save_to_disk = optional(bool, false)<br/>      path         = optional(string, "~/.kube/config")<br/>      owerwrite    = optional(bool, false)<br/>    }), {})<br/>  })</pre> | `{}` | no |



## Resources

| Name | Type |
|------|------|
| [local_sensitive_file.kubeconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [local_sensitive_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [dns_a_record_set.control_plane_nodes](https://registry.terraform.io/providers/hashicorp/dns/latest/docs/data-sources/a_record_set) | data source |
| [dns_a_record_set.worker_nodes](https://registry.terraform.io/providers/hashicorp/dns/latest/docs/data-sources/a_record_set) | data source |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/cluster_health) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |
| [talos_machine_disks.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_disks) | data source |

## Outputs

| Name | Description |
|------|-------------|
| healthy | True once cluster is healthy |
| kubeconfig | The Talos cluster kubeconfig |
| talosconfig | The Talos cluster talosconfig |
| worker\_disks | Talos workernode disks |

<!-- END_TF_DOCS -->