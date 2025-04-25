terraform {
  backend "azurerm" {}
}

# entra group for admins
resource "azuread_group" "entra_admin_group" {
  count            = var.deploy ? 1 : 0
  display_name     = "grp-aks-admin"
  security_enabled = true
}

# Add the currently running service principal to the above group
resource "azuread_group_member" "entra_admin_member" {
  count            = var.deploy ? 1 : 0
  group_object_id  = azuread_group.entra_admin_group[0].object_id
  member_object_id = data.azurerm_client_config.current.object_id
}

# resourcegroup for aks and acr
resource "azurerm_resource_group" "rg" {
  count    = var.deploy ? 1 : 0
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Create a subnet for AKS
resource "azurerm_subnet" "aks_subnet" {
  count                = var.deploy ? 1 : 0
  name                 = var.subnet_name
  resource_group_name  = var.vnet_resource_group_name
  virtual_network_name = var.vnetname
  address_prefixes     = [var.subnet_address_prefix]
}

# Create an Azure Container Registry for your images
resource "azurerm_container_registry" "acr" {
  count               = var.deploy ? 1 : 0
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Create an AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.deploy ? 1 : 0
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "akspoc"
  
network_profile {
  network_plugin    = "azure"
}

  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = var.nodeskusize
    vnet_subnet_id      = azurerm_subnet.aks_subnet[0].id
    max_pods = 50

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = [azuread_group.entra_admin_group[0].object_id]
    tenant_id              = data.azurerm_client_config.current.tenant_id
  }

  depends_on = [
    azurerm_subnet.aks_subnet
  ]
}

resource "azurerm_role_assignment" "acrtoaks" {
  count                            = var.deploy ? 1 : 0
  principal_id                     = azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id
  role_definition_name             = "AcrPush"
  scope                            = azurerm_container_registry.acr[0].id
  skip_service_principal_aad_check = true
}

# Grant AKS the Network Contributor role on the subnet
resource "azurerm_role_assignment" "aks_subnet_role" {
  count                = var.deploy ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.aks[0].identity[0].principal_id
  role_definition_name = "Network Contributor"
  scope                = azurerm_subnet.aks_subnet[0].id
}

output "kube_config" {
  value     = var.deploy ? azurerm_kubernetes_cluster.aks[0].kube_config_raw : null
  sensitive = true
}

output "acr_login_server" {
  value = var.deploy ? azurerm_container_registry.acr[0].login_server : null
}

output "acr_admin_username" {
  value = var.deploy ? azurerm_container_registry.acr[0].admin_username : null
}

output "acr_admin_password" {
  value     = var.deploy ? azurerm_container_registry.acr[0].admin_password : null
  sensitive = true
}

output "aks_cluster_id" {
  value = var.deploy ? azurerm_kubernetes_cluster.aks[0].id : null
}

output "aks_subnet_id" {
  value = var.deploy ? azurerm_subnet.aks_subnet[0].id : null
}