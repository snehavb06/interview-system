# terraform/modules/function-app/main.tf
resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Locally redundant storage for India
  min_tls_version          = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                     = var.tags
}

resource "azurerm_service_plan" "this" {
  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"
  sku_name            = var.service_plan_sku
  tags                = var.tags
}

resource "azurerm_windows_function_app" "this" {
  name                = var.function_app_name
  resource_group_name = var.resource_group_name
  location            = var.location

  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key
  service_plan_id            = azurerm_service_plan.this.id

  functions_extension_version = "~4"
  builtin_logging_enabled     = false
  https_only                  = true

  site_config {
    always_run = true
    use_32_bit_worker = false
    application_stack {
      dotnet_version = "v8.0"
    }
    
    cors {
      allowed_origins = [
        "https://portal.azure.com",
        "https://localhost:3000",
        "https://${var.function_app_name}.azurewebsites.net"
      ]
    }
    
    application_insights_connection_string = var.application_insights_connection_string
  }

  app_settings = merge({
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"
    "WEBSITE_TIME_ZONE"        = "India Standard Time"
    "AzureSignalRConnectionString" = var.signalr_connection_string
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.application_insights_connection_string
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "WEBSITE_ENABLE_SYNC_UPDATE_SITE" = "true"
  }, var.extra_app_settings)

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "function_app_name" {
  type = string
}

variable "service_plan_name" {
  type = string
}

variable "service_plan_sku" {
  type    = string
  default = "Y1"
}

variable "application_insights_connection_string" {
  type    = string
  default = ""
  sensitive = true
}

variable "signalr_connection_string" {
  type    = string
  default = ""
  sensitive = true
}

variable "extra_app_settings" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "function_app_name" {
  value = azurerm_windows_function_app.this.name
}

output "function_app_default_hostname" {
  value = azurerm_windows_function_app.this.default_hostname
}

output "function_app_id" {
  value = azurerm_windows_function_app.this.id
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "application_insights_connection_string" {
  value     = var.application_insights_connection_string
  sensitive = true
}