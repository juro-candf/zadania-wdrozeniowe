data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "zw"
  sku_tier            = "Free"

default_node_pool {
  name                 = "system"
  vm_size              = var.node_vm_size
  auto_scaling_enabled = true
  min_count            = 1
  max_count            = var.max_node_count
  os_disk_size_gb      = 30
}

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }
}
