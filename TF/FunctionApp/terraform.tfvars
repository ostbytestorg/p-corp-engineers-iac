location               = "norwayeast"
resource_group_name    = "rg-tf-functionapp"
tags                   = { configuration = "terraform" }
storage_account_name   = "sttfsicrafuncapp001"
storage_container_name = "function-code"
function_blob_name     = "function_app_code.zip"
zip_file_path          = "./FUNCTION_APP_CODE.zip"
service_plan_name      = "appplan-sicratffunc001"
function_app_name      = "sicratffunc001"