/**
 * # pippi.io/talos-cluster
 *
 * This Terraform module automates the configuration of a Talos cluster.
 *
 */

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

# Generate machine secrets for Talos cluster
resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.cluster.nodes

  node                        = coalesce(each.value.temporary_ip, each.key)
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.value.type].machine_configuration

  config_patches = [
    replace( # trim newlines
      templatefile("${path.module}/templates/machine.yaml.tmpl", {
        type                  = each.value.type
        cluster_endpoint      = var.cluster.hostname
        hostname              = coalesce(each.value.hostname, each.key)
        install_disk          = each.value.install_disk
        disks                 = each.value.disks
        encryption            = var.cluster.encryption
        image                 = try(coalesce(each.value.image, var.cluster.image), null)
        time_servers          = var.cluster.time_servers
        nameservers           = var.cluster.nameservers
        kubeadm_cert_lifetime = var.cluster.kubeadm_cert_lifetime
        interfaces = { for id, interface in each.value.interfaces :
          id => merge(interface, {
            routes = coalesce(interface.routes, var.cluster.default_routes)
          })
        }
    }), "/\\n\\n+/", "\n"),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = coalesce(each.value.hostname, each.key)
    }),
  ]
}

resource "talos_machine_bootstrap" "this" {
  node                 = keys(local.control_plane_nodes)[0]
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_machine_configuration_apply.this]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = keys(local.control_plane_nodes)[0]

  depends_on = [talos_machine_bootstrap.this]
}

data "dns_a_record_set" "control_plane_nodes" {
  for_each = local.control_plane_nodes

  host = each.key
}

data "dns_a_record_set" "worker_nodes" {
  for_each = local.worker_nodes

  host = each.key
}

data "talos_cluster_health" "this" {
  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = [for _ in data.dns_a_record_set.control_plane_nodes : _.addrs[0]]
  worker_nodes         = [for _ in data.dns_a_record_set.worker_nodes : _.addrs[0]]
  endpoints            = [var.cluster.hostname]

  timeouts = {
    read = "10m"
  }

  depends_on = [
    talos_machine_bootstrap.this,
    talos_machine_configuration_apply.this,
  ]
}

data "talos_machine_disks" "this" {
  for_each = local.worker_nodes

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = each.key
  selector             = var.cluster.disk_selector
}

locals {
  worker_disks = { for _ in flatten([
    for node, data in data.talos_machine_disks.this : [
      for disk in coalesce(data.disks, []) : {
        node        = node
        dev_path    = disk.dev_path
        system      = disk.dev_path == var.cluster.nodes[node].install_disk
        model       = disk.model
        pretty_size = disk.pretty_size
        size        = disk.size
        rotational  = disk.rotational
        wwid        = disk.wwid
        symlinks    = disk.symlinks
  }]]) : format("%s%s", _.node, _.dev_path) => _ }
}
