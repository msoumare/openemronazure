param location string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'openemr-kv'
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

output kvName string = kv.name
