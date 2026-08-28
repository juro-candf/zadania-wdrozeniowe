terraform {
  backend "azurerm" {
    resource_group_name  = "replace-with-your-rgn"
    storage_account_name = "sttfstatezw4732"
    container_name       = "tfstate"
    key                  = "aks.tfstate"
  }
}