output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}

output "get_credentials_command" {
  value = "az aks get-credentials --resource-group ${azurerm_kubernetes_cluster.main.resource_group_name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "kong_proxy_service_command" {
  value = "kubectl get svc -n kong kong-kong-proxy"
}
