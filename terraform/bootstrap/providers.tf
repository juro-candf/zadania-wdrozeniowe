provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id

  # sandbox subscription doesn't allow the RP-registration Terraform normally attempts
  skip_provider_registration = true
}
