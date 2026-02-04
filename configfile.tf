locals {
  talosconfig_path = pathexpand(var.configfile.talosconfig.path)
  new_talosconfig  = sensitive(yamldecode(data.talos_client_configuration.this.talos_config))
  old_talosconfig  = sensitive(try(yamldecode(file(local.talosconfig_path)), {}))

  kubeconfig_path = pathexpand(var.configfile.kubeconfig.path)
  new_kubeconfig  = sensitive(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw))
  old_kubeconfig = sensitive(try(yamldecode(file(local.kubeconfig_path)), {
    clusters = []
    contexts = []
    users    = []
  }))

  all_kubeconfig_clusters = values(merge(
    { for _ in local.old_kubeconfig.clusters : _.name => _ },
    { one(local.new_kubeconfig.clusters).name = one(local.new_kubeconfig.clusters) }
  ))
  all_kubeconfig_contexts = values(merge(
    { for _ in local.old_kubeconfig.contexts : _.name => _ },
    { one(local.new_kubeconfig.contexts).name = one(local.new_kubeconfig.contexts) }
  ))
  all_kubeconfig_users = values(merge(
    { for _ in local.old_kubeconfig.users : _.name => _ },
    { one(local.new_kubeconfig.users).name = one(local.new_kubeconfig.users) }
  ))
}

resource "local_sensitive_file" "kubeconfig" {
  count = var.configfile.kubeconfig.save_to_disk ? 1 : 0

  filename = local.kubeconfig_path
  content = var.configfile.kubeconfig.owerwrite ? talos_cluster_kubeconfig.this.kubeconfig_raw : yamlencode({
    kind            = "Config"
    apiVersion      = "v1"
    clusters        = local.all_kubeconfig_clusters
    contexts        = local.all_kubeconfig_contexts
    users           = local.all_kubeconfig_users
    current-context = local.new_kubeconfig.current-context
  })
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  count = var.configfile.talosconfig.save_to_disk ? 1 : 0

  filename = local.talosconfig_path
  content = var.configfile.talosconfig.owerwrite ? yamlencode(local.new_talosconfig) : yamlencode({
    context  = local.new_talosconfig.context
    contexts = merge(try(local.old_talosconfig.contexts, {}), local.new_talosconfig.contexts)
  })
  file_permission = "0600"
}
