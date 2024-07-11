param location string = resourceGroup().location
param applicationName string = 'hexalz'
param enviromentName string = 'dev'

param frontDoorName string = 'fd-${applicationName}-${enviromentName}'
param applicationInsightsName string = 'ai-${applicationName}-${enviromentName}-${location}-001'
param storageAccountName string = 'st${applicationName}${location}001'
param containerRegistryName string = 'acr${applicationName}${enviromentName}${location}'
param appServicePlanName string = 'asp-${applicationName}-${enviromentName}-${location}-001'
param appServiceName string = 'as-${applicationName}-${enviromentName}-${location}'

var linuxFxVersion = 'php|7.4'

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
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
  name: containerRegistryName
  location: location
  sku: {
    name: 'Standard'
  }

  properties: {
    adminUserEnabled: true
  }
}

resource serverFarm 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
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
  name: appServiceName
  location: location
  properties: {
    serverFarmId: serverFarm.id
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

resource appSettings 'Microsoft.Web/sites/config@2023-12-01' = {
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
              backendHostHeader: '${applicationName}.azurewebsites.net'
              address: '${applicationName}.azurewebsites.net'
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
