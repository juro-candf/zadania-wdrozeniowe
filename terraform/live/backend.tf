terraform {
  backend "azurerm" {
    resource_group_name  = "cf-int-az-sbx-juro-2026-08-28-32022"
    storage_account_name = "sttfstatezw4732"
    container_name       = "tfstate"
    key                  = "aks.tfstate"
  }
}