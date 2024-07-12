param location string = resourceGroup().location
param applicationName string = 'hexalz'
param enviromentName string = 'dev'

var frontDoorEndpointName = 'afd-e-${applicationName}-${enviromentName}'
var frontDoorProfileName = 'afd-p-${applicationName}-${enviromentName}'
var frontDoorOriginGroupName = '${applicationName}OriginGroup'
var frontDoorOriginName = '${applicationName}AppServiceOrigin'
var frontDoorRouteName = '${applicationName}Route'
var frontDoorSkuName = 'Standard_AzureFrontDoor'

// param wafPolicyName string = 'waf-${applicationName}-${enviromentName}'
var applicationInsightsName = 'ai-${applicationName}-${enviromentName}-${location}-001'
var storageAccountName = 'st${applicationName}${location}001'
var containerRegistryName = 'acr${applicationName}${enviromentName}${location}'
var appServicePlanName = 'asp-${applicationName}-${enviromentName}-${location}-001'
var appServiceName = 'as-${applicationName}-${enviromentName}-${location}'
var linuxFxVersion = 'php|7.4'

//********* Application Insights *********
//****************************************

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

//********* Storage Account *********
//***********************************

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

//********* Azure Container Registry *********
//********************************************

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

//********* Web App *********
//***************************

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
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

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
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

resource appStorageSetting 'Microsoft.Web/sites/config@2023-12-01' = {
  name: 'azurestorageaccounts'
  parent: app
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
  parent: app
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

//********* Azure Front Doors *********
//*************************************

resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: app.properties.defaultHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: app.properties.defaultHostName
    priority: 1
    weight: 1000
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}
