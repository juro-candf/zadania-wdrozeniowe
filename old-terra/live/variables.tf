variable "location" {
  type    = string
  default = "westeurope"
}

variable "resource_group_name" {
  type    = string
  default = "rg-zw-aks"
}

variable "cluster_name" {
  type    = string
  default = "aks-zw"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "max_node_count" {
  type    = number
  default = 3
}

variable "backend_image_tag" {
  type    = string
  default = "latest"
}

variable "frontend_image_tag" {
  type    = string
  default = "latest"
}

variable "postgres_user" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_db" {
  type    = string
  default = "coolpeople"
}
