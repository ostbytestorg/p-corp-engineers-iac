data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnetname
  resource_group_name = var.vnet_resource_group_name
}