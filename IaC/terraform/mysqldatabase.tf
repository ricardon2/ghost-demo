# resource "azurerm_mysql_flexible_database" "mysql_database_prod" {
#   name                = "ghost"
#   resource_group_name = data.azurerm_resource_group.active_rg.name
#   server_name         = azurerm_mysql_flexible_server.prod.name
#   charset             = "utf8"
#   collation           = "utf8_unicode_ci"
# }