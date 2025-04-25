terraform {
  backend "azurerm" {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg_function_app" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "function_app_storage_account" {
  name                          = var.storage_account_name
  resource_group_name           = azurerm_resource_group.rg_function_app.name
  location                      = azurerm_resource_group.rg_function_app.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = true
}

resource "azurerm_storage_container" "function_code_container" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.function_app_storage_account.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "function_app_service_plan" {
  name                = var.service_plan_name
  location            = azurerm_resource_group.rg_function_app.location
  resource_group_name = azurerm_resource_group.rg_function_app.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "example_function_app" {
  name                          = var.function_app_name
  location                      = azurerm_resource_group.rg_function_app.location
  resource_group_name           = azurerm_resource_group.rg_function_app.name
  service_plan_id               = azurerm_service_plan.function_app_service_plan.id
  storage_account_name          = azurerm_storage_account.function_app_storage_account.name
  storage_uses_managed_identity = true
  public_network_access_enabled = true

  site_config {
    application_stack {
      powershell_core_version = "7.4"
    }
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "function_app_role" {
  scope                = azurerm_storage_account.function_app_storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.example_function_app.identity.0.principal_id

  depends_on = [
    azurerm_linux_function_app.example_function_app
  ]
}
