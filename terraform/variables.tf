variable "prefix" {
  description = "Prefix for all resource names across both clouds"
  type        = string
  default     = "druid-poc"
}

variable "aws_region" {
  description = "AWS region for EKS and S3"
  type        = string
  default     = "us-east-1"
}

variable "azure_location" {
  description = "Azure region for AKS and Blob Storage"
  type        = string
  default     = "eastus"
}
