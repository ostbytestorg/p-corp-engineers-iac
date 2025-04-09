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

variable "aks_cluster_name" {
  type    = string
}

variable "acr_name" {
  type    = string
}

variable "deploy" {
  type    = bool
  default = true
}