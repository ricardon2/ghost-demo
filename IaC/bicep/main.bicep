var env_prefix = 'ghostpoc'
var frontDoorName = 'ghost-FrontDoor'

param location string = resourceGroup().location
param linuxFxVersion string = 'php|7.4'

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'active-appinsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${env_prefix}prod'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'

  resource blobService 'blobServices@2023-05-01' = {
    name: 'default'

    resource container 'containers@2023-05-01' = {
     name: 'databaseblob'
     properties: {
      publicAccess: 'None'
     }
    }
  }

  resource fileService 'fileServices@2023-05-01' = {
    name: 'default'

    resource fileShare 'shares@2023-05-01' = {
     name: 'contentfiles'
     properties: {
      shareQuota: 50
     }
    }
  }
}

resource containerregistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: '${env_prefix}activecr'
  location: location
  sku: {
    name: 'Standard'
  }

  properties: {
    adminUserEnabled: true
  }
}

resource serviceplan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${env_prefix}-prod-app-service-plan'
  location: location
  kind: 'linux'

  sku: {
    name: 'S1'
  }
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: env_prefix
  location: location
  properties: {
    serverFarmId: serviceplan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      ftpsState: 'FtpsOnly'
      alwaysOn: true

      ipSecurityRestrictions: [
        {
            ipAddress: 'AzureFrontDoor.Backend'
            tag: 'ServiceTag'
            priority: 300
            name: 'FrontDoorOnly'
        }
      ]

    }
    httpsOnly: true
  }
  dependsOn: [
    storageAccount
  ]
}

resource storageSetting 'Microsoft.Web/sites/config@2023-12-01' = {
  name: 'azurestorageaccounts'
  parent: webApp
  properties: {
    ContentBlobVolume: {
      type: 'AzureBlob'
      shareName: storageAccount::blobService::container.name
      mountPath: '/var/lib/ghost/content_blob'
      accountName: storageAccount.name
      accessKey: storageAccount.listKeys().keys[0].value
    }

    ContentFilesVolume: {
      type: 'AzureFiles'
      shareName: storageAccount::fileService::fileShare.name
      mountPath: '/var/lib/ghost/content_files'
      accountName: storageAccount.name
      accessKey: storageAccount.listKeys().keys[0].value
    }
  }
}

resource ipSecurityRestrictionsSetting 'Microsoft.Web/sites/config@2023-12-01' = {
  name: 'appsettings'
  parent: webApp
  properties: {
    WEBSITES_PORT: '2368'
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'true'
    NODE_ENV: 'development'
    url: 'https://ghost-FrontDoor.azurefd.net'
    GHOST_CONTENT: '/var/lib/ghost/content_files/'
    paths__contentPath: '/var/lib/ghost/content_files/'
    privacy__useUpdateCheck: 'false'
    DOCKER_REGISTRY_SERVER_URL: containerregistry.properties.loginServer
    DOCKER_REGISTRY_SERVER_USERNAME: containerregistry.listCredentials().username
    DOCKER_REGISTRY_SERVER_PASSWORD: containerregistry.listCredentials().passwords[0].value
    APPINSIGHTS_INSTRUMENTATIONKEY: appinsights.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appinsights.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
  }
}

resource frontDoors 'Microsoft.Network/frontDoors@2021-06-01' = {
  name: frontDoorName
  location: 'global'

  properties: {
    backendPoolsSettings: {
      enforceCertificateNameCheck: 'Disabled'
    }

    frontendEndpoints: [
      {
        id: 'ghostFrontendEndpoint'
        name: 'ghostFrontendEndpoint'
        properties: {
          hostName: '${frontDoorName}.azurefd.net'
        }
      }
    ]

    loadBalancingSettings: [
      {
        name: 'ghostLoadBalancingSettings'
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
        }
      }
    ]

    routingRules: [
      {
        name: 'ghostBlogRoutingRule'
        properties: {
          acceptedProtocols: [
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontDoors/frontEndEndpoints', frontDoorName, 'ghostFrontendEndpoint')
            }
          ]
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            backendPool: {
              id: resourceId('Microsoft.Network/frontDoors/backEndPools', frontDoorName, 'ghostBackendBing')
            }
            forwardingProtocol: 'MatchRequest'
          }
        }
      }
    ]
    backendPools: [
      {
        name: 'ghostBackendBing'
        properties: {
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontDoors/loadBalancingSettings', frontDoorName, 'ghostLoadBalancingSettings')
          }
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontDoors/healthProbeSettings', frontDoorName, 'ghostHealthProbeSetting')
          }
          backends: [
            {
              priority: 1
              backendHostHeader: '${env_prefix}.azurewebsites.net'
              address: '${env_prefix}.azurewebsites.net'
              httpPort: 80
              httpsPort: 443
              weight: 1
            }
          ]
        }
      }
    ]
    healthProbeSettings: [
      {
        id: 'ghostHealthProbeSetting'
        name: 'ghostHealthProbeSetting'
        properties: {
          enabledState: 'Enabled'
          protocol: 'Https'
          healthProbeMethod: 'HEAD'
          path: '/'
          intervalInSeconds: 30
        }        
      }
    ]
  }
}
