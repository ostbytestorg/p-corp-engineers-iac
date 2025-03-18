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
  name                     = "sttfsicrafuncapp001"
  resource_group_name      = azurerm_resource_group.rg_function_app.name
  location                 = azurerm_resource_group.rg_function_app.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = true
}

resource "azurerm_storage_container" "function_code_container" {
  name                  = "function-code"
  storage_account_id = azurerm_storage_account.function_app_storage_account.id
  container_access_type = "private"
}

# upload the zipped file to the container
resource "azurerm_storage_blob" "storage_blob_function" {
  name                   = "function_app_code.zip" # name of the blob in the contianer
  source                 =  "./FUNCTION_APP_CODE.ZIP" # path to the zip file
  content_md5            = filemd5("./FUNCTION_APP_CODE.ZIP") # check if the zip file has changed
  storage_account_name   = azurerm_storage_account.function_app_storage_account.name
  storage_container_name = "function-code"
  type                   = "Block"
}