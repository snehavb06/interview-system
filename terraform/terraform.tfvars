# terraform/terraform.tfvars.example
environment = "dev"
location    = "centralindia"  # Options: centralindia, southindia, westindia
project_name = "interview-system"

# Your Azure credentials
tenant_id      = "e05455be-e3eb-417e-a2d1-1d5872d61586"
subscription_id = "66a7b046-11b4-488f-8e16-b4fc3a028d62"

# Admin email for alerts (use a real email)
admin_email    = "admin@yourcompany.com"

# API Client ID from App Registration
api_client_id  = "24ba1caa-d536-4199-ad1b-c52581e37596"

# Optional: RBAC assignments
admin_objects = {
  # "user1" = "object-id-of-user1"
}

# SKU configurations for India region
signalr_sku    = "Free_F1"  # Free tier available in India
function_sku   = "Y1"        # Consumption plan