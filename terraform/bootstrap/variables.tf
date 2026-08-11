variable "subscription_id" {
  description = "Azure subscription ID to deploy into (your sandbox subscription)."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Short prefix used to name resources (letters/numbers only, lowercase recommended)."
  type        = string
  default     = "sandbox"
}

variable "resource_group_name" {
  description = "Name of the pre-existing resource group to deploy the AKS cluster into (sandbox identities are typically scoped to one specific group)."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Leave null to use the current default version from Azure."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS control plane SKU tier. 'Free' has no SLA and is cheapest, ideal for a sandbox."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of: Free, Standard, Premium."
  }
}

variable "node_count" {
  description = "Number of nodes in the default system node pool."
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "VM size for the default system node pool."
  type        = string
  default     = "Standard_B2s_v2"
}

variable "enable_auto_scaling" {
  description = "Whether to enable the cluster autoscaler on the default node pool."
  type        = bool
  default     = false
}

variable "min_node_count" {
  description = "Minimum node count when autoscaling is enabled."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum node count when autoscaling is enabled."
  type        = number
  default     = 3
}

variable "network_plugin" {
  description = "AKS network plugin (kubenet is cheaper/simpler for a sandbox; azure gives full VNet integration)."
  type        = string
  default     = "kubenet"

  validation {
    condition     = contains(["kubenet", "azure"], var.network_plugin)
    error_message = "network_plugin must be either 'kubenet' or 'azure'."
  }
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    environment = "sandbox"
    managed_by  = "terraform"
  }
}
