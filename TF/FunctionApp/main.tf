terraform {
  backend "azurerm" {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg_function_app" {
  name     = "rg-tf-functionapp"
  location = "norwayeast"
  tags = {
    "configuration" = "terraform"
  }
}