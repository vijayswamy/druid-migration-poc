output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.poc.name
}

output "aks_resource_group" {
  description = "AKS resource group"
  value       = azurerm_resource_group.poc.name
}

output "storage_account_name" {
  description = "Azure Storage Account name for Druid deep storage"
  value       = azurerm_storage_account.druid.name
}

output "storage_account_key" {
  description = "Azure Storage Account primary access key"
  value       = azurerm_storage_account.druid.primary_access_key
  sensitive   = true
}

output "storage_container_name" {
  description = "Azure Blob container name"
  value       = azurerm_storage_container.druid_segments.name
}
