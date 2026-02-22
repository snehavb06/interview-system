# terraform/modules/apim/main.tf
resource "azurerm_api_management" "this" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name
  
  # India region specific settings
  public_network_access_enabled = true
  virtual_network_type          = "None"
  
  tags = var.tags
}

resource "azurerm_api_management_api" "this" {
  name                = var.api_name
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = var.api_display_name
  path                = var.api_path
  protocols           = ["https"]
  service_url         = var.function_app_url
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "start_interview" {
  operation_id        = "start-interview"
  api_name            = azurerm_api_management_api.this.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  display_name        = "Start Interview"
  method              = "POST"
  url_template        = "/StartInterview"
}

resource "azurerm_api_management_api_operation" "negotiate" {
  operation_id        = "negotiate"
  api_name            = azurerm_api_management_api.this.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  display_name        = "SignalR Negotiate"
  method              = "POST"
  url_template        = "/negotiate"
}

resource "azurerm_api_management_api_operation" "broadcast" {
  operation_id        = "broadcast"
  api_name            = azurerm_api_management_api.this.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  display_name        = "Broadcast Message"
  method              = "POST"
  url_template        = "/broadcastToInterview"
}

resource "azurerm_api_management_api_policy" "jwt_policy" {
  api_name            = azurerm_api_management_api.this.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <validate-azure-ad-token tenant-id="${var.tenant_id}" audience="${var.api_client_id}" />
    <rate-limit calls="100" renewal-period="60" />
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>https://${var.function_app_default_hostname}</origin>
        <origin>http://localhost:3000</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "apim_name" {
  type = string
}

variable "publisher_name" {
  type = string
}

variable "publisher_email" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "Consumption"
}

variable "api_name" {
  type    = string
  default = "interview-api"
}

variable "api_display_name" {
  type    = string
  default = "Interview API"
}

variable "api_path" {
  type    = string
  default = "interview"
}

variable "function_app_url" {
  type = string
}

variable "function_app_default_hostname" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "api_client_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "apim_id" {
  value = azurerm_api_management.this.id
}

output "apim_gateway_url" {
  value = azurerm_api_management.this.gateway_url
}

output "apim_name" {
  value = azurerm_api_management.this.name
}