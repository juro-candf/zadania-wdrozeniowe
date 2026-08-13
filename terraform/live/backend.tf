terraform {
  backend "azurerm" {
    resource_group_name  = "cf-int-az-sbx-juro-2026-08-13-44812"
    storage_account_name = "sttfstatezw4221"
    container_name       = "tfstate"
    key                  = "aks.tfstate"
  }
}