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

resource "azurerm_storage_account" "function_app_storage_account" {
  name                          = "sttfsicrafuncapp001"
  resource_group_name           = azurerm_resource_group.rg_function_app.name
  location                      = azurerm_resource_group.rg_function_app.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = true
}

resource "azurerm_storage_container" "function_code_container" {
  name                  = "function-code"
  storage_account_id    = azurerm_storage_account.function_app_storage_account.id
  container_access_type = "private"
}

# upload the zipped file to the container
resource "azurerm_storage_blob" "storage_blob_function" {
  name                   = "function_app_code.zip"            # name of the blob in the contianer
  source                 = "./FUNCTION_APP_CODE.zip"          # path to the zip file
  content_md5            = filemd5("./FUNCTION_APP_CODE.zip") # check if the zip file has changed
  storage_account_name   = azurerm_storage_account.function_app_storage_account.name
  storage_container_name = "function-code"
  type                   = "Block"
}

resource "azurerm_service_plan" "function_app_service_plan" {
  name                = "appplan-sicratffunc001"
  location            = azurerm_resource_group.rg_function_app.location
  resource_group_name = azurerm_resource_group.rg_function_app.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "example_function_app" {
  name                          = "sicratffunc001"
  location                      = azurerm_resource_group.rg_function_app.location
  resource_group_name           = azurerm_resource_group.rg_function_app.name
  service_plan_id               = azurerm_service_plan.function_app_service_plan.id
  storage_account_name          = azurerm_storage_account.function_app_storage_account.name
  storage_uses_managed_identity = true
  public_network_access_enabled = true

  app_settings = {
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.function_app_storage_account.name
    "HASH"                             = base64encode(filesha256("./FUNCTION_APP_CODE.zip"))
    "WEBSITE_RUN_FROM_PACKAGE"         = azurerm_storage_blob.storage_blob_function.url
  }

  site_config {
    application_stack {
      powershell_core_version = "7.4"
    }
    cors {
      allowed_origins = ["portal.azure.com"]
    }
  }

  identity {
    type = "SystemAssigned" # Use managed identity over access keys
  }
}

resource "azurerm_role_assignment" "function_app_role" {
  scope                = azurerm_storage_account.function_app_storage_account.id
  role_definition_name = "Storage Blob Data Contributor"

  principal_id         = azurerm_linux_function_app.example_function_app.identity.0.principal_id #Principle ID of the function app
  depends_on = [
    azurerm_linux_function_app.example_function_app # Ensure the fucntion app is fully provisioned before assigning roles
  ]
}