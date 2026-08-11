terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatezw<suffix>"
    container_name       = "tfstate"
    key                  = "aks.tfstate"
  }
}