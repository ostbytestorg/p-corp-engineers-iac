terraform {
  backend "azurerm" {}
}

data "azurerm_client_config" "current" {}

# resourcegroup for aks and acr
resource "azurerm_resource_group" "rg_dns" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
# Create the DNS zone
resource "azurerm_dns_zone" "dns_zone" {
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.rg_dns.name
}

# Output the name servers for the DNS zone
output "dns_name_servers" {
  value = azurerm_dns_zone.dns_zone.name_servers
}