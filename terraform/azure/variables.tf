variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "druid-poc"
}
