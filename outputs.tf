output "azurerm_kubernetes_cluster_main_object_id" {
  description = "value of the object id of the service principal"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
  sensitive   = true
}

output "azurerm_kubernetes_cluster_main_kube_config_host" {
  description = "value of the host of the kube config"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive   = true
}

output "azurerm_kubernetes_cluster_main_kube_config_client_certificate" {
  description = "value of the client certificate of the kube config"
  value       = azurerm_kubernetes_cluster.main.kube_admin_config[0].client_certificate
  sensitive   = true
}

output "azurerm_kubernetes_cluster_main_kube_config_client_key" {
  description = "value of the client key of the kube config"
  value       = azurerm_kubernetes_cluster.main.kube_admin_config[0].client_key
  sensitive   = true
}

output "azurerm_kubernetes_cluster_main_kube_config_cluster_ca_certificate" {
  description = "value of the cluster ca certificate of the kube config"
  value       = azurerm_kubernetes_cluster.main.kube_admin_config[0].cluster_ca_certificate
  sensitive   = true
}

output "azurerm_kubernetes_cluster_main_kube_config_cluster_raw" {
  description = "value of the cluster raw of the kube config"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "aks_id" {
  description = "The `azurerm_kubernetes_cluster`'s id."
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_name" {
  description = "The `aurerm_kubernetes-cluster`'s name."
  value       = azurerm_kubernetes_cluster.main.name
}

output "azurerm_log_analytics_workspace_id" {
  description = "The id of the created Log Analytics workspace"
  value       = try(azurerm_log_analytics_workspace.main[0].id, null)
}

output "azurerm_log_analytics_workspace_name" {
  description = "The name of the created Log Analytics workspace"
  value       = try(azurerm_log_analytics_workspace.main[0].name, null)
}

output "azurerm_log_analytics_workspace_primary_shared_key" {
  description = "Specifies the workspace key of the log analytics workspace"
  sensitive   = true
  value       = try(azurerm_log_analytics_workspace.main[0].primary_shared_key, null)
}
