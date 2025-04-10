location                = "norwayeast"
resource_group_name     = "rg-tf-aks"
tags                    = { configuration = "terraform" }
aks_cluster_name        = "aksostbyengineeering001"
acr_name                = "acrostbyengineering001"
deploy                  = true
vnetname                = "vnet-spoke-production-engineers"
nodeskusize             = "Standard_B4ms"
vnet_resource_group_name = "alz-norwayeast-spoke-networking"
subnet_name             = "subnet-aks-engineers"
subnet_address_prefix   = "10.0.136.0/23"