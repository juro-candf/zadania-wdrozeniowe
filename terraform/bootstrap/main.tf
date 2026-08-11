resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  cluster_name = "aks-${var.prefix}-${random_string.suffix.result}"
  dns_prefix   = "${var.prefix}-${random_string.suffix.result}"
}

# sandbox identity only has rights on this pre-existing resource group, not the subscription
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  dns_prefix          = local.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    node_count           = var.enable_auto_scaling ? null : var.node_count
    enable_auto_scaling = var.enable_auto_scaling
    min_count            = var.enable_auto_scaling ? var.min_node_count : null
    max_count            = var.enable_auto_scaling ? var.max_node_count : null
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = var.network_plugin
  }
}
