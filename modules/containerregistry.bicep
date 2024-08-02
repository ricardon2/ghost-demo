@description('required. container registry name')
param containerRegistryName string

@description('required. resource group location')
param location string

@description('required. key vault name to store password')
param keyVaultName string

resource containerregistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }

  properties: {
    adminUserEnabled: true
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
    metadataSearch: 'Disabled'
  }
}

module secret 'br:acrbiceptemplatespoc.azurecr.io/secret:v1' = {
  name: 'acr-password'
  params: {
    keyVaultName: keyVaultName
    secretName: '${containerRegistryName}-password'
    secretValue: containerregistry.listCredentials().passwords[0].value
  }
}

@description('login server url')
output loginServer string = containerregistry.properties.loginServer

@description('user name')
var userName = containerregistry.listCredentials().username
output userName string = userName

@description('secret uri with version')
output secretUriWithVersion string = secret.outputs.secretUriWithVersion
