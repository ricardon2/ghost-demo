# resource "azurerm_mysql_flexible_server" "prod" {
#   name                = "${var.env_prefix}-prod"
#   location            = data.azurerm_resource_group.active_rg.location
#   resource_group_name = data.azurerm_resource_group.active_rg.name

#   administrator_login          = "${var.mysql_administrator_login}"
#   administrator_password = "${var.mysql_administrator_login_password}"

#   sku_name   = "B_Standard_B1s"
#   version    = "5.7"

#   backup_retention_days             = 7
# }

# resource "azurerm_mysql_flexible_server_firewall_rule" "prod" {
#   name                = "AllowAccessToAzureServices"
#   resource_group_name = data.azurerm_resource_group.active_rg.name
#   server_name         = azurerm_mysql_flexible_server.prod.name
#   start_ip_address    = "0.0.0.0"
#   end_ip_address      = "0.0.0.0"
# }