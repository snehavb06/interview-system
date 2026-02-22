# terraform/modules/governance/main.tf
resource "azurerm_role_definition" "interview_admin" {
  name        = var.custom_role_name
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Can manage interview system resources in India region"

  permissions {
    actions = [
      "Microsoft.Web/sites/*",
      "Microsoft.SignalRService/SignalR/*",
      "Microsoft.ApiManagement/service/*",
      "Microsoft.Insights/Components/*",
      "Microsoft.OperationalInsights/workspaces/*",
      "Microsoft.Resources/subscriptions/resourceGroups/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    "/subscriptions/${var.subscription_id}",
    var.resource_group_id
  ]
}

resource "azurerm_role_assignment" "interview_admin" {
  for_each = var.admin_assignees

  scope              = var.resource_group_id
  role_definition_id = azurerm_role_definition.interview_admin.role_definition_resource_id
  principal_id       = each.value
}

# Policy Definition for India region compliance
resource "azurerm_policy_definition" "enforce_india_tags" {
  name         = "enforce-india-region-tags"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Enforce India region tags"
  description  = "Ensures all resources have India region tags"

  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "in": [
          "Microsoft.Resources/subscriptions/resourceGroups",
          "Microsoft.Web/sites",
          "Microsoft.SignalRService/SignalR",
          "Microsoft.ApiManagement/service"
        ]
      },
      {
        "field": "tags['Region']",
        "notEquals": "India"
      }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
POLICY_RULE
}

# Policy Assignment
resource "azurerm_resource_group_policy_assignment" "enforce_tags" {
  name                 = "enforce-india-tags"
  resource_group_id    = var.resource_group_id
  policy_definition_id = azurerm_policy_definition.enforce_india_tags.id
}

variable "subscription_id" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "admin_assignees" {
  type    = map(string)
  default = {}
}

variable "custom_role_name" {
  type    = string
  default = "Interview Administrator India"
}

variable "location" {
  type    = string
  default = "centralindia"
}

output "role_definition_id" {
  value = azurerm_role_definition.interview_admin.role_definition_resource_id
}