output "talosconfig" {
  description = "The Talos cluster talosconfig"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "The Talos cluster kubeconfig"
  value = {
    host                   = yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).clusters[0].cluster.server
    cluster_ca_certificate = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).users[0].user.client-certificate-data)
    client_key             = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).users[0].user.client-key-data)
    raw                    = talos_cluster_kubeconfig.this.kubeconfig_raw
  }
  sensitive = true
}

output "healthy" {
  description = "True once cluster is healthy"
  value       = can(data.talos_cluster_health.this.id)
}

output "worker_disks" {
  description = "Talos workernode disks"
  value       = local.worker_disks
}
