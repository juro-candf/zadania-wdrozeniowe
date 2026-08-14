terraform {
  backend "azurerm" {
    resource_group_name  = "cf-int-az-sbx-juro-2026-08-14-80436"
    storage_account_name = "sttfstatezw2478"
    container_name       = "tfstate"
    key                  = "aks.tfstate"
  }
}