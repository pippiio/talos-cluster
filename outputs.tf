output "talosconfig" {
  description = "The Talos cluster talosconfig"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "The Talos cluster kubeconfig"
  value       = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive   = true
}
