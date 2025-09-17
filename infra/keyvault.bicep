param location string
param keyVaultName string
param mysqlAdminUser string
@secure()
param mysqlAdminPassword string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
  }
}

// Store MySQL username in KV
resource mysqlUserSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'mysql-admin-user'
  properties: {
    value: mysqlAdminUser
  }
}

// Store MySQL password in KV
resource mysqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'mysql-admin-password'
  properties: {
    value: mysqlAdminPassword
  }
}

output kvName string = kv.name
output mysqlUserSecretUri string = mysqlUserSecret.properties.secretUri
output mysqlPasswordSecretUri string = mysqlPasswordSecret.properties.secretUri
