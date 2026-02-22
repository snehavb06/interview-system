# terraform/variables.tf
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for India (centralindia, southindia, westindia)"
  type        = string
  default     = "centralindia"  # Pune region
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "interview-system"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "InterviewSystem"
    ManagedBy   = "Terraform"
    Environment = "dev"
    Region      = "India"
    Repository  = "https://github.com/YOUR_USERNAME/interview-system"
  }
}

variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Admin email for notifications"
  type        = string
}

variable "admin_objects" {
  description = "Map of admin object IDs for RBAC"
  type        = map(string)
  default     = {}
}

variable "api_client_id" {
  description = "API Client ID for JWT validation"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub token for GitHub Actions"
  type        = string
  sensitive   = true
  default     = ""
}

variable "signalr_sku" {
  description = "SignalR SKU for India region (Free_F1, Standard_S1)"
  type        = string
  default     = "Free_F1"  # Free tier available in India regions
}

variable "function_sku" {
  description = "Function App SKU (Y1 for Consumption, EP1 for Premium)"
  type        = string
  default     = "Y1"
}