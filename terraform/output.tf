# terraform/outputs.tf
output "function_app_name" {
  description = "Name of the function app"
  value       = module.function_app.function_app_name
}

output "function_app_default_hostname" {
  description = "Default hostname of the function app"
  value       = module.function_app.function_app_default_hostname
}

output "function_app_url" {
  description = "URL of the function app"
  value       = "https://${module.function_app.function_app_default_hostname}"
}

output "apim_gateway_url" {
  description = "Gateway URL of API Management"
  value       = module.apim.apim_gateway_url
}

output "signalr_connection_string" {
  description = "Primary connection string for SignalR"
  value       = module.signalr.primary_connection_string
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = module.function_app.application_insights_connection_string
  sensitive   = true
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "azure_region" {
  description = "Azure region (India)"
  value       = var.location
}

output "deployment_region" {
  description = "Deployment location in India"
  value       = "Azure India - ${var.location == "centralindia" ? "Pune" : var.location == "southindia" ? "Chennai" : "Mumbai"}"
}