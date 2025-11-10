locals {
  node_types          = toset([for node in values(var.cluster.nodes) : node.type])
  control_plane_nodes = { for k, v in var.cluster.nodes : k => v if v.type == "controlplane" }
  worker_nodes        = { for k, v in var.cluster.nodes : k => v if v.type == "worker" }
}

data "talos_machine_configuration" "this" {
  for_each = local.node_types

  machine_type     = each.key
  cluster_name     = var.cluster.name
  cluster_endpoint = format("https://%s:6443", var.cluster.hostname)
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  endpoints            = keys(local.control_plane_nodes)
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_machine_bootstrap.this]
}

# # Generate machine secrets for Talos cluster
resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.cluster.nodes

  node                        = each.key
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.value.type].machine_configuration

  config_patches = [
    replace( # trim newlines
      templatefile("${path.module}/templates/machine.yaml.tmpl", {
        cluster_endpoint = var.cluster.hostname
        hostname         = each.key
        install_disk     = each.value.disk
        interfaces = { for id, interface in each.value.interfaces :
          id => merge(interface, {
            routes = coalesce(interface.routes, var.cluster.default_routes)
          })
        }
        # default_routes = var.cluster.default_routes
    }), "/\\n\\n+/", "\n")
  ]
}

resource "talos_machine_bootstrap" "this" {
  node                 = keys(local.control_plane_nodes)[0]
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_machine_configuration_apply.this]
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = keys(local.control_plane_nodes)[0]

  depends_on = [talos_machine_bootstrap.this]
}

data "talos_cluster_health" "this" {
  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = keys(local.control_plane_nodes)
  worker_nodes         = keys(local.worker_nodes)
  endpoints            = [var.cluster.hostname]
}
