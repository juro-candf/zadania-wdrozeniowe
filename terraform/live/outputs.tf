output "resource_group_name" {
  description = "Name of the resource group containing the AKS cluster."
  value       = data.azurerm_resource_group.this.name
}

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "kube_config" {
  description = "Raw kubeconfig for the cluster. Marked sensitive; use `terraform output -raw kube_config > kubeconfig` to save it."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "host" {
  description = "Kubernetes API server endpoint."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive   = true
}
