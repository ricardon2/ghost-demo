resource "azurerm_application_insights" "ai_appservice_active" {
  name                = "active-appinsights"
  location            = data.azurerm_resource_group.active_rg.location
  resource_group_name = data.azurerm_resource_group.active_rg.name
  application_type    = "Node.JS"
}