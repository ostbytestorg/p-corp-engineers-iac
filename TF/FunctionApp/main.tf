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

# Add Key Vault resource with RBAC mode enabled
resource "azurerm_key_vault" "function_app_key_vault" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.rg_function_app.location
  resource_group_name         = azurerm_resource_group.rg_function_app.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
  
  # Enable RBAC mode
  enable_rbac_authorization = true
}

# Assign Key Vault Administrator role to the deploying principal
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.function_app_key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
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

  # Add an app setting to reference the key vault
  app_settings = {
    "KEYVAULT_ENDPOINT" = azurerm_key_vault.function_app_key_vault.vault_uri
  }
}

# Assign Key Vault Secrets User role to the Function App's managed identity
resource "azurerm_role_assignment" "function_app_kv_secrets_user" {
  scope                = azurerm_key_vault.function_app_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.example_function_app.identity.0.principal_id

  depends_on = [
    azurerm_linux_function_app.example_function_app
  ]
}

resource "azurerm_role_assignment" "function_app_role" {
  scope                = azurerm_storage_account.function_app_storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.example_function_app.identity.0.principal_id

  depends_on = [
    azurerm_linux_function_app.example_function_app
  ]
}