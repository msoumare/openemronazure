param location string
param mysqlConnection string
param storageKey string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'openemr-kv'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enabledForDeployment: true
  }
}

resource mysqlSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${kv.name}/mysql-connection'
  properties: {
    value: mysqlConnection
  }
}

resource storageSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${kv.name}/storage-key'
  properties: {
    value: storageKey
  }
}

output mysqlConnectionSecretUri string = mysqlSecret.properties.secretUri
