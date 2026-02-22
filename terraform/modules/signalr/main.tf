# terraform/modules/signalr/main.tf
resource "azurerm_signalr_service" "this" {
  name                = var.signalr_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.sku_name
    capacity = var.sku_capacity
  }

  service_mode = var.service_mode
  
  # India region specific settings
  public_network_access_enabled = true
  local_auth_enabled            = true
  aad_auth_enabled              = false
  
  tags = var.tags
}

# SignalR connection string output for India region
resource "azurerm_signalr_service_network_acl" "this" {
  count = var.configure_network_acl ? 1 : 0

  signalr_service_id = azurerm_signalr_service.this.id
  default_action     = "Allow"

  public_network {
    allowed_request_types = ["ClientConnection", "ServerConnection", "RESTAPI"]
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "signalr_name" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "Free_F1"
}

variable "sku_capacity" {
  type    = number
  default = 1
}

variable "service_mode" {
  type    = string
  default = "Serverless"
}

variable "configure_network_acl" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "id" {
  value = azurerm_signalr_service.this.id
}

output "hostname" {
  value = azurerm_signalr_service.this.hostname
}

output "primary_access_key" {
  value     = azurerm_signalr_service.this.primary_access_key
  sensitive = true
}

output "primary_connection_string" {
  value     = azurerm_signalr_service.this.primary_connection_string
  sensitive = true
}

output "secondary_access_key" {
  value     = azurerm_signalr_service.this.secondary_access_key
  sensitive = true
}

output "secondary_connection_string" {
  value     = azurerm_signalr_service.this.secondary_connection_string
  sensitive = true
}