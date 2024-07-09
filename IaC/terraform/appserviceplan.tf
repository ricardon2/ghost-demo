resource "azurerm_service_plan" "prod" {
  name                = "${var.env_prefix}-prod-app-service-plan"
  location            = data.azurerm_resource_group.active_rg.location
  resource_group_name = data.azurerm_resource_group.active_rg.name
  os_type             = "Linux"
  sku_name            = "S1"
}