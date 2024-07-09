resource "azurerm_container_registry" "acr_active" {
  name                = "${var.env_prefix}activecr"
  resource_group_name = data.azurerm_resource_group.active_rg.name
  location            = data.azurerm_resource_group.active_rg.location
  sku                 = "Standard"
  admin_enabled       = true
}
