# terraform/modules/resource-group/variables.tf
variable "name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region (India)"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}