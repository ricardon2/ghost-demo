@description('required: key vault name')
param keyVaultName string = ''

@description('where the resource must be deployed')
param location string = resourceGroup().location

@description('required: shortened name of the application this resource will work with')
@minLength(3)
param applicationName string = 'hexalz'

@description('required: enviroment resource belongs')
@minLength(3)
param enviromentName string = 'dev'

var applicationInsightsName = 'ai-${applicationName}-${enviromentName}-${location}'

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

module appInsightsInstrumentationSecret 'br:acrbiceptemplatespoc.azurecr.io/web/secret:v1' = {
  name: '${applicationInsightsName}-instrumentationkey'
  params: {
    keyVaultName: keyVaultName
    secretName: '${applicationInsightsName}-instrumentationkey'
    secretValue: appinsights.properties.InstrumentationKey
  }
}

module appInsightsConnectionSecret 'br:acrbiceptemplatespoc.azurecr.io/web/secret:v1' = {
  name: '${applicationInsightsName}-connectionstring'
  params: {
    keyVaultName: keyVaultName
    secretName:'${applicationInsightsName}-connectionstring'
    secretValue: appinsights.properties.ConnectionString
  }
}

@description('Instrumentation key name')
output appInsightsInstrumentationKeySecrettName string = appInsightsInstrumentationSecret.name

@description('connection string name')
output appInsightsappInsightsConnectionStringSecretName string = appInsightsConnectionSecret.name
