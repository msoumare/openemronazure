targetScope = 'resourceGroup'

param location string
param acrName string = 'openemracr'
param mysqlAdminUser string
@secure()
param mysqlAdminPassword string
param storageAccountName string = 'openemrstorage'
param userAssignedIdentityName string = 'openemr-aca-identity'

// --------------------
// Key Vault
// --------------------
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'openemr-kv'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
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

// --------------------
// User Assigned Identity
// --------------------
module uami './uami.bicep' = {
  name: 'uami-deploy'
  params: {
    location: location
    userAssignedIdentityName: userAssignedIdentityName
  }
}

// --------------------
// RBAC: grant UAMI access to Key Vault
// --------------------
module rbac './rbac.bicep' = {
  name: 'rbac-deploy'
  params: {
    principalId: uami.outputs.uamiPrincipalId
    keyVaultName: kv.name
  }
}

module rbacStorage './rbac-storage' = {
  name: 'rbac-storage'
  params: {
    principalId: uami.outputs.uamiPrincipalId
    resourceId: storage.outputs.storageAccountId
    resourceType: 'Microsoft.Storage/storageAccounts'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a7264617-510b-4343-a828-9731dc254ea7' // Storage File Data SMB Share Contributor
    )
  }
}

// --------------------
// ACR
// --------------------
module acr './acr.bicep' = {
  name: 'acr-deploy'
  params: {
    location: location
    acrName: acrName
  }
}

// --------------------
// MySQL (reads from KV secrets)
// --------------------
module mysql './mysql.bicep' = {
  name: 'mysql-deploy'
  params: {
    location: location
    mysqlUserSecretUri: mysqlUserSecret.properties.secretUri
    mysqlPasswordSecretUri: mysqlPasswordSecret.properties.secretUri
  }
}

// --------------------
// Storage
// --------------------
module storage './storage.bicep' = {
  name: 'storage-deploy'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// --------------------
// Logs + App Insights
// --------------------
module logs './loganalytics.bicep' = {
  name: 'logs-deploy'
  params: {
    location: location
  }
}

module appInsights './appinsights.bicep' = {
  name: 'ai-deploy'
  params: {
    location: location
    workspaceId: logs.outputs.workspaceId
  }
}

// --------------------
// ACA (uses UAMI to fetch secrets from KV)
// --------------------
module aca './aca.bicep' = {
  name: 'aca-deploy'
  params: {
    location: location
    acrServer: acr.outputs.acrServer
    mysqlUserSecretUri: mysqlUserSecret.properties.secretUri
    mysqlPasswordSecretUri: mysqlPasswordSecret.properties.secretUri
    storageShareName: storage.outputs.fileShareName
    storageAccountId: storage.outputs.storageAccountId
    appInsightsKey: appInsights.outputs.instrumentationKey
    userAssignedIdentityId: uami.outputs.uamiId
  }
}
