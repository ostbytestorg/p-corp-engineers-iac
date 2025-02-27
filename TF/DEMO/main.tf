terraform {
  backend "azurerm" {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg_demo" {
  name     = "rg-tf-demo"
  location = "norwayeast"
}

module "avm-res-keyvault-vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.9.1"
  # insert the 4 required variables here
  tenant_id = data.azurerm_client_config.current.tenant_id
  resource_group_name = azurerm_resource_group.rg_demo.name
  name = "kvpcorpengineers001"
  location = azurerm_resource_group.rg_demo.location
}