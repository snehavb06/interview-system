# terraform/main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg-india"
    storage_account_name = "tfstateinterviewindia"
    container_name       = "tfstate"
    key                  = "interview-system-india.tfstate"
  }
}

# Configure Azure Provider for India region
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
  # India region is specified in each resource
}

provider "azuread" {
  # Use Azure CLI authentication
}

# Generate random suffix for unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  resource_group_name = "${var.project_name}-${var.environment}-rg-india"
  suffix              = random_string.suffix.result
  
  # Names with india suffix
  function_app_name      = "${var.project_name}-func-india-${local.suffix}"
  storage_account_name   = "${replace(var.project_name, "-", "")}india${local.suffix}"
  service_plan_name      = "${var.project_name}-plan-india-${local.suffix}"
  app_insights_name      = "${var.project_name}-insights-india-${local.suffix}"
  apim_name              = "${var.project_name}-apim-india-${local.suffix}"
  signalr_name           = "${var.project_name}-signalr-india-${local.suffix}"
  log_analytics_name     = "${var.project_name}-logs-india-${local.suffix}"
  
  # URLs
  function_app_url = "https://${local.function_app_name}.azurewebsites.net"
  
  # Tags
  common_tags = merge(var.tags, {
    Environment = var.environment
    DeployedBy  = "Terraform"
    AzureRegion = var.location
    Country     = "India"
  })
}

# Resource Group Module (India region)
module "resource_group" {
  source   = "./modules/resource-group"
  name     = local.resource_group_name
  location = var.location  # centralindia, southindia, or westindia
  tags     = local.common_tags
}

# SignalR Module (India region)
module "signalr" {
  source = "./modules/signalr"
  
  resource_group_name = module.resource_group.name
  location            = var.location
  signalr_name        = local.signalr_name
  sku_name            = var.signalr_sku
  service_mode        = "Serverless"
  tags                = local.common_tags
  
  depends_on = [module.resource_group]
}

# Monitoring Module (India region)
module "monitoring" {
  source = "./modules/monitoring"
  
  resource_group_name           = module.resource_group.name
  location                      = var.location
  log_analytics_workspace_name  = local.log_analytics_name
  app_insights_name             = local.app_insights_name
  action_group_name             = "${var.project_name}-alerts-india"
  admin_email                   = var.admin_email
  tags                          = local.common_tags
  
  depends_on = [module.resource_group]
}

# Function App Module (India region)
module "function_app" {
  source = "./modules/function-app"
  
  resource_group_name            = module.resource_group.name
  location                       = var.location
  storage_account_name           = local.storage_account_name
  function_app_name              = local.function_app_name
  service_plan_name              = local.service_plan_name
  service_plan_sku               = var.function_sku
  app_insights_name              = local.app_insights_name
  log_analytics_workspace_id     = module.monitoring.log_analytics_workspace_id
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  signalr_connection_string      = module.signalr.primary_connection_string
  tags                           = local.common_tags
  
  extra_app_settings = {
    "WEBSITE_TIME_ZONE"          = "India Standard Time"
    "FUNCTIONS_WORKER_RUNTIME"   = "dotnet-isolated"
    "INTERVIEW_TENANT_ID"        = var.tenant_id
    "GITHUB_REPOSITORY"          = "https://github.com/YOUR_USERNAME/interview-system"
    "REGION"                     = var.location
  }
  
  depends_on = [module.resource_group, module.signalr, module.monitoring]
}

# API Management Module (India region)
module "apim" {
  source = "./modules/apim"
  
  resource_group_name            = module.resource_group.name
  location                       = var.location
  apim_name                      = local.apim_name
  publisher_name                 = "Interview System India"
  publisher_email                = var.admin_email
  api_name                       = "interview-api-india"
  api_display_name               = "Interview API India"
  api_path                       = "interview"
  function_app_url               = local.function_app_url
  function_app_default_hostname  = module.function_app.function_app_default_hostname
  tenant_id                      = var.tenant_id
  api_client_id                  = var.api_client_id
  tags                           = local.common_tags
  
  depends_on = [module.function_app]
}

# Governance Module
module "governance" {
  source = "./modules/governance"
  
  subscription_id           = var.subscription_id
  resource_group_id         = module.resource_group.id
  admin_assignees           = var.admin_objects
  custom_role_name          = "Interview Administrator India"
  location                  = var.location
  
  depends_on = [module.resource_group]
}

# Output values
output "resource_group_name" {
  value = module.resource_group.name
}

output "function_app_name" {
  value = module.function_app.function_app_name
}

output "function_app_url" {
  value = "https://${module.function_app.function_app_default_hostname}"
}

output "apim_gateway_url" {
  value = module.apim.apim_gateway_url
}

output "signalr_hostname" {
  value = module.signalr.hostname
}

output "region" {
  value = var.location
  description = "Azure region (India)"
}