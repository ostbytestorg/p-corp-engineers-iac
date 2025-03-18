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
  sku_name            = "P0v3"
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
    "FUNCTIONS_WORKER_RUNTIME"         = "powershell" # Set runtime to PowerShell
    "FUNCTIONS_EXTENSION_VERSION"      = "~4"         # Recommended Functions runtime version
  }

  site_config {
    always_on = true # Prevents idle timeout (important for PowerShell triggers, timers, etc.)
    application_stack {
      powershell_core_version = "7.4"
    }
  }

  identity {
    type = "SystemAssigned" # Use managed identity over access keys
  }
}
