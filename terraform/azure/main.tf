terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "poc" {
  name     = "${var.prefix}-rg"
  location = var.azure_location
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "poc" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.poc.location
  resource_group_name = azurerm_resource_group.poc.name
  dns_prefix          = "${var.prefix}-aks"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_DC2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled = true

  tags = {
    Environment = "poc"
    Project     = "druid-migration"
  }
}

# Storage Account — Druid deep storage
resource "azurerm_storage_account" "druid" {
  name                     = "${replace(var.prefix, "-", "")}druid"
  resource_group_name      = azurerm_resource_group.poc.name
  location                 = azurerm_resource_group.poc.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = "poc"
    Project     = "druid-migration"
  }
}

# Blob Container — where Druid segments will live
resource "azurerm_storage_container" "druid_segments" {
  name                  = "druid-segments"
  storage_account_name  = azurerm_storage_account.druid.name
  container_access_type = "private"
}
