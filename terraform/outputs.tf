output "eks_cluster_name" {
  description = "AWS EKS cluster name (source)"
  value       = module.aws.eks_cluster_name
}

output "s3_bucket_name" {
  description = "S3 bucket for Druid deep storage (source)"
  value       = module.aws.s3_bucket_name
}

output "aws_region" {
  description = "AWS region"
  value       = module.aws.aws_region
}

output "aks_cluster_name" {
  description = "Azure AKS cluster name (destination)"
  value       = module.azure.aks_cluster_name
}

output "aks_resource_group" {
  description = "Azure resource group"
  value       = module.azure.aks_resource_group
}

output "azure_storage_account" {
  description = "Azure Storage Account for Druid deep storage (destination)"
  value       = module.azure.storage_account_name
}

output "azure_storage_container" {
  description = "Azure Blob container name"
  value       = module.azure.storage_container_name
}
