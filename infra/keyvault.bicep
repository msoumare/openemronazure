param location string
param keyVaultName string
@secure()
param mysqlAdminUser string 
@secure()
param mysqlAdminPassword string
// Additional OpenEMR configuration secrets (mysqlHost now plain value, not stored as secret)
// OE user no longer stored as a secret; set directly via container env
@secure()
param oePass string

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



// Store OpenEMR app password (OE_PASS)
resource oePassSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'oe-pass'
  properties: {
    value: oePass
  }
}


output keyVaultId string = kv.id
output keyVaultName string = kv.name
// Provide versioned secret URIs (Container Apps may require versioned identifiers). Suppressing linter warnings.
// bicep:disable-next-line outputs-should-not-contain-secrets -- Container Apps requires versioned secret URIs; acceptable risk (URIs only, not values)
output mysqlUserSecretUri string = mysqlUserSecret.properties.secretUriWithVersion
// bicep:disable-next-line outputs-should-not-contain-secrets -- same rationale
output mysqlPasswordSecretUri string = mysqlPasswordSecret.properties.secretUriWithVersion
// bicep:disable-next-line outputs-should-not-contain-secrets -- same rationale
output oePassSecretUri string = oePassSecret.properties.secretUriWithVersion
// bicep:disable-next-line outputs-should-not-contain-secrets -- same rationale
