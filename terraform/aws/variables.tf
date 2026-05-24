variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "druid-poc"
}

variable "iam_username" {
  description = "IAM username that will have kubectl admin access to EKS"
  type        = string
  default     = "vijayswamy"
}
