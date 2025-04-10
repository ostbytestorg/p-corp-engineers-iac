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

variable "vnetname" {
  type = string
}

variable "nodeskusize" {
  type = string
  default = "Standard_B2s"
}

variable "vnet_resource_group_name" {
  description = "Name of the resource group containing the VNet"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet for AKS"
  type        = string
}

variable "subnet_address_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
}