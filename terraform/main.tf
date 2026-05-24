terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# AWS Module — EKS + S3
module "aws" {
  source     = "./aws"
  aws_region = var.aws_region
  prefix     = var.prefix
}

# Azure Module — AKS + Blob Storage
module "azure" {
  source         = "./azure"
  azure_location = var.azure_location
  prefix         = var.prefix
}
