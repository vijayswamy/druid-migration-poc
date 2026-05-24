output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket name for Druid deep storage"
  value       = aws_s3_bucket.druid_deep_storage.bucket
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
