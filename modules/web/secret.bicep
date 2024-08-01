@description('required: key vault name')
param keyVaultName string

@description('required: name of the secret')
param secretName string

@secure()
@description('required: ')
param secretValue string

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

resource kvSecret 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: secretName
  parent: keyVault
  properties: {
    value: secretValue
  }
}
