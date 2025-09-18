param location string
param keyVaultName string
@secure()
param mysqlAdminUser string 
@secure()
param mysqlAdminPassword string
// Additional OpenEMR configuration secrets
param mysqlHost string
param oeUser string
@secure()
param oePass string
param timezone string = 'UTC'

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

// Store MySQL host (not highly sensitive but keep in KV for consistent retrieval pattern)
resource mysqlHostSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'mysql-host'
  properties: {
    value: mysqlHost
  }
}

// Store OpenEMR app user (OE_USER)
resource oeUserSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'oe-user'
  properties: {
    value: oeUser
  }
}

// Store OpenEMR app password (OE_PASS)
resource oePassSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'oe-pass'
  properties: {
    value: oePass
  }
}

// Store timezone selection
resource timezoneSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'timezone'
  properties: {
    value: timezone
  }
}

output keyVaultId string = kv.id
output keyVaultName string = kv.name
// Intentionally NOT outputting secret URIs to avoid exposing secret metadata and to satisfy linter rule.
