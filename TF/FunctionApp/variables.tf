variable "resource_group_name" {
  description = "The name of the resource group in which to create the function app."
  type        = string
}

variable "location" {
  description = "The Azure Region in which to create the function app."
  type        = string
}

variable "storage_account_name" {
  description = "The name of the storage account."
  type        = string
}

variable "storage_container_name" {
  description = "The name of the storage container."
  type        = string
  default     = "function-code"
}

variable "service_plan_name" {
  description = "The name of the service plan."
  type        = string
}

variable "function_app_name" {
  description = "The name of the function app."
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to the resources."
  type        = map(string)
  default     = {}
}

variable "key_vault_name" {
  description = "The name of the key vault."
  type        = string
}