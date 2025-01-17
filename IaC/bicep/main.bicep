param location string = resourceGroup().location
@minLength(3)
param applicationName string = 'hexalz'
@minLength(3)
param enviromentName string = 'dev'

param keyVaultName string = 'kv-alz-dev-001'

var frontDoorEndpointName = 'afd-e-${applicationName}-${enviromentName}'
var frontDoorProfileName = 'afd-p-${applicationName}-${enviromentName}'
var frontDoorOriginGroupName = '${applicationName}OriginGroup'
var frontDoorOriginName = '${applicationName}AppServiceOrigin'
var frontDoorRouteName = '${applicationName}Route'
var frontDoorSkuName = 'Standard_AzureFrontDoor'

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

//********* Key Vault ***************
//***********************************

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
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

  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }

  resource blobService 'blobServices@2023-05-01' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {
        allowPermanentDelete: false
        enabled: false
      }
    }

    resource container 'containers@2023-05-01' = {
     name: 'databaseblob'
     properties: {
      publicAccess: 'None'
      defaultEncryptionScope: '$account-encryption-key'
      denyEncryptionScopeOverride: false
     }
    }
  }

  resource fileService 'fileServices@2023-05-01' = {
    name: 'default'

    properties: {
      shareDeleteRetentionPolicy: {
        days: 7
        enabled: true
      }
    }

    resource fileShare 'shares@2023-05-01' = {
     name: 'contentfiles'
     properties: {
      shareQuota: 50
      accessTier: 'TransactionOptimized'
     }
    }
  }
}

//********* Azure Container Registry *********
//********************************************

module containerRegistryModule 'br:acrbiceptemplatespoc.azurecr.io/containerregistry:v1' = {
  name: 'deploy-acr'
  params: {
    containerRegistryName: containerRegistryName
    keyVaultName: keyVaultName
    location: location
  }
}

//********* Web App *********
//***************************

module appServicePlan 'br/public:avm/res/web/serverfarm:0.2.2' = {
  name: 'avm-server-farm-deployment'
  params: {
    name: appServicePlanName
    location: location
    kind: 'Linux'
    skuName: 'S1'
    reserved: true
    skuCapacity: 1
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    serverFarmId: appServicePlan.outputs.resourceId
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

// Configure Key Vault Secrets User permission
var roleDefinitionId = '4633458b-17de-408a-b874-0445c86b69e6'
var roleAssignmentName= guid(keyVault.id, roleDefinitionId, resourceGroup().id)
resource keyVaultSecretReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: app.identity.principalId
  }
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
    url: 'https://${frontDoorEndpoint.properties.hostName}'
    GHOST_CONTENT: '/var/lib/ghost/content_files/'
    paths__contentPath: '/var/lib/ghost/content_files/'
    privacy__useUpdateCheck: 'false'
    DOCKER_REGISTRY_SERVER_URL: containerRegistryModule.outputs.loginServer
    DOCKER_REGISTRY_SERVER_USERNAME: containerRegistryModule.outputs.userName
    DOCKER_REGISTRY_SERVER_PASSWORD: '@Microsoft.KeyVault(SecretUri=${containerRegistryModule.outputs.secretUriWithVersion})'
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
  properties: {
    originResponseTimeoutSeconds: 30
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
