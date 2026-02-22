# terraform/modules/monitoring/main.tf
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = var.app_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.this.id
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "this" {
  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = substr(var.action_group_name, 0, 12)

  email_receiver {
    name                    = "send-to-admin"
    email_address           = var.admin_email
    use_common_alert_schema = true
  }

  tags = var.tags
}

# Alert for India business hours (IST timezone)
resource "azurerm_monitor_metric_alert" "failed_orchestrations" {
  name                = "Failed-Orchestrations-Alert-India"
  resource_group_name = var.resource_group_name
  scopes              = var.function_app_id != "" ? [var.function_app_id] : []
  description         = "Alert when functions fail (India region)"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  enabled             = var.function_app_id != ""

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }

  tags = var.tags
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "log_analytics_workspace_name" {
  type = string
}

variable "retention_in_days" {
  type    = number
  default = 30
}

variable "app_insights_name" {
  type = string
}

variable "action_group_name" {
  type    = string
  default = "interview-alerts-india"
}

variable "admin_email" {
  type = string
}

variable "function_app_id" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.this.name
}

output "application_insights_id" {
  value = azurerm_application_insights.this.id
}

output "application_insights_instrumentation_key" {
  value     = azurerm_application_insights.this.instrumentation_key
  sensitive = true
}

output "application_insights_connection_string" {
  value     = azurerm_application_insights.this.connection_string
  sensitive = true
}

output "action_group_id" {
  value = azurerm_monitor_action_group.this.id
}