resource "azurerm_linux_web_app" "prod" {
  name                = "${var.env_prefix}"
  location            = data.azurerm_resource_group.active_rg.location
  resource_group_name = data.azurerm_resource_group.active_rg.name
  service_plan_id     = azurerm_service_plan.prod.id

  site_config {
    always_on          = true
    ip_restriction     = [
      {
        service_tag               = "AzureFrontDoor.Backend",
        name                      = "FrontDoorOnly"
        description               = "Make sure user wont be accessing the application using its url"
        priority                  = 300
        action                    = "Allow"
        headers = []
        ip_address = null
        virtual_network_subnet_id = null
      }
    ]
  }

  app_settings = {
    #Settings for ghost
    # database__client                            = "mysql"
    # database__connection__host                  = "${azurerm_mysql_flexible_server.prod.name}.mysql.database.azure.com"
    # database__connection__port                  = "3306"
    # database__connection__user                  = "${var.mysql_administrator_login}@${azurerm_mysql_flexible_server.prod.name}"
    # database__connection__password              = "${var.mysql_administrator_login_password}"
    # database__connection__database              = "ghost"
    # database__connection__ssl                   = "true"
    # database__connection__ssl_minVersion        = "TLSv1.2"
    WEBSITES_PORT                               = "2368"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE         = "true"
    NODE_ENV                                    = "development"
    url                                         = "https://ghost-FrontDoor.azurefd.net"
    GHOST_CONTENT                               = "/var/lib/ghost/content_files/"
    paths__contentPath	                        = "/var/lib/ghost/content_files/"
    privacy__useUpdateCheck	                    = "false"
    #Settings for private Container Registries
    DOCKER_REGISTRY_SERVER_URL                  = "https://${azurerm_container_registry.acr_active.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME             = "${azurerm_container_registry.acr_active.admin_username}"
    DOCKER_REGISTRY_SERVER_PASSWORD             = "${azurerm_container_registry.acr_active.admin_password}"
    #Settings for application insights
    APPINSIGHTS_INSTRUMENTATIONKEY              = "${azurerm_application_insights.ai_appservice_active.instrumentation_key}"
    APPLICATIONINSIGHTS_CONNECTION_STRING       = "${azurerm_application_insights.ai_appservice_active.connection_string}"
    ApplicationInsightsAgent_EXTENSION_VERSION  = "~2"
  }

    storage_account {
    name          = "ContentBlobVolume"
    type          = "AzureBlob"
    account_name  = "${azurerm_storage_account.prod.name}"
    share_name    = "${azurerm_storage_container.prod.name}"
    access_key    = "${azurerm_storage_account.prod.primary_access_key}"
    mount_path    = "/var/lib/ghost/content_blob"
  }

  storage_account {
    name          = "ContentFilesVolume"
    type          = "AzureFiles"
    account_name  = "${azurerm_storage_account.prod.name}"
    share_name    = "${azurerm_storage_share.prod.name}"
    access_key    = "${azurerm_storage_account.prod.primary_access_key}"
    mount_path    = "/var/lib/ghost/content_files"
  } 
}