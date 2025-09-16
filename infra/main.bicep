targetScope = 'resourceGroup'

param location string
param acrName string = 'openemracr'
param mysqlAdminUser string
@secure()
param mysqlAdminPassword string
param storageAccountName string = 'openemrstorage'

// Create Key Vault
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

// Deploy ACR
module acr './acr.bicep' = {
  name: 'acr-deploy'
  params: {
    location: location
    acrName: acrName
  }
}

// Deploy MySQL (reads secrets from KV)
module mysql './mysql.bicep' = {
  name: 'mysql-deploy'
  params: {
    location: location
    mysqlUserSecretUri: mysqlUserSecret.properties.secretUri
    mysqlPasswordSecretUri: mysqlPasswordSecret.properties.secretUri
  }
}

// Deploy Storage
module storage './storage.bicep' = {
  name: 'storage-deploy'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// Deploy Logs + App Insights
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

// Deploy ACA, referencing KV secrets
module aca './aca.bicep' = {
  name: 'aca-deploy'
  params: {
    location: location
    acrServer: acr.outputs.acrServer
    mysqlUserSecretUri: mysqlUserSecret.properties.secretUri
    mysqlPasswordSecretUri: mysqlPasswordSecret.properties.secretUri
    storageShareName: storage.outputs.fileShareName
    appInsightsKey: appInsights.outputs.instrumentationKey
  }
}
