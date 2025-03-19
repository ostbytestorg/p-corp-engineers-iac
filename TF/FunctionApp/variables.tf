variable "location" {
  description = "Azure region to deploy resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "tags" {
  description = "Tags to use on resources"
  type        = map(string)
}

variable "storage_account_name" {
  description = "Name of the storage account for the function app"
  type        = string
}

variable "storage_container_name" {
  description = "Name of the storage container for the function code"
  type        = string
}

variable "function_blob_name" {
  description = "Blob name for the uploaded zipped function app code"
  type        = string
}

variable "zip_file_path" {
  description = "Path to the zipped function app code"
  type        = string
}

variable "service_plan_name" {
  description = "Name of the App Service plan for the function app"
  type        = string
}

variable "function_app_name" {
  description = "Name of the Linux Function App"
  type        = string
}