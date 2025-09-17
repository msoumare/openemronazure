targetScope = 'subscription'

@secure()
param mysqlAdminPassword string
param mysqlAdminUser string 
param location string = 'eastus'
param resourceGroupName string
param acaEnvironmentName string = 'cae-openemr-dev-${location}' 
param containerAppName string = 'ca-openemr-dev-${location}'
param acrName string = 'acr-openemr-dev-${location}'
param appInsightsName string = 'appi-openemr-dev-${location}'
param keyVaultName string = 'kv-openemr-dev-${location}'
param logAnalyticsName string = 'log-openemr-dev-${location}'
param mySqlName string = 'mysql-openemr-dev-${location}'
param storageAccountName string = 'sa-openemr-dev-${location}'
param userAssignedIdentityName string = 'uai-openemr-dev-${location}'

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
}

// Deploy KeyVault
module keyvault './keyvault.bicep' = {
  name: 'kv-deploy'
  scope: rg
  params: {
    location: location
    keyVaultName: keyVaultName
    mysqlAdminUser: mysqlAdminUser
    mysqlAdminPassword: mysqlAdminPassword    
  }
}

// Deploy ACR
module acr './acr.bicep' = {
  name: 'acr-deploy'
  scope: rg
  params: {
    location: location
    acrName: acrName
  }
}

// Deploy MySQL (reads secrets from KV)
module mysql './mysql.bicep' = {
  name: 'mysql-deploy'
  scope: rg
  params: {
    location: location
    mySqlName: mySqlName
    mysqlUserSecretUri: keyvault.outputs.mysqlUserSecretUri
    mysqlPasswordSecretUri: keyvault.outputs.mysqlPasswordSecretUri
  }
}

// Deploy Storage
module storage './storage.bicep' = {
  name: 'storage-deploy'
  scope: rg
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// Deploy Logs + App Insights
module logs './loganalytics.bicep' = {
  name: 'logs-deploy'
  scope: rg
  params: {
    logAnalyticsName: logAnalyticsName
    location: location
  }
}

module appInsights './appinsights.bicep' = {
  name: 'ai-deploy'
  scope: rg
  params: {
    location: location
    workspaceId: logs.outputs.workspaceId
    appInsightsName: appInsightsName
  }
}

// --------------------
// User Assigned Identity
// --------------------
module uami './uami.bicep' = {
  name: 'uami-deploy'
  scope: rg
  params: {
    location: location
    userAssignedIdentityName: userAssignedIdentityName
  }
}

// --------------------
// RBAC: grant UAMI access to Key Vault
// --------------------
module rbac './rbac-keyvault.bicep' = {
  name: 'rbac-keyvault-deploy'
  scope: rg
  params: {
    principalId: uami.outputs.uamiPrincipalId
    keyVaultName: keyvault.outputs.keyVaultName
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    )    
  }
}

module rbacStorage './rbac-storage.bicep' = {
  name: 'rbac-storage-deploy'
  scope: rg
  params: {
    principalId: uami.outputs.uamiPrincipalId
    storageAccountName: storage.outputs.storageAccountName
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a7264617-510b-4343-a828-9731dc254ea7' // Storage File Data SMB Share Contributor
    )    
  }
}

module rbacAcr './rbac-acr.bicep' = {
  name: 'rbac-acr-deploy'
  scope: rg
  params: {
    principalId: uami.outputs.uamiPrincipalId
    acrName: acr.outputs.acrName
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d' // Built-in role definition ID for AcrPull
    )    
  }
}

// --------------------
// ACA (uses UAMI to fetch secrets from KV)
// --------------------
module aca './aca.bicep' = {
  name: 'aca-deploy'
  scope: rg
  params: {
    location: location
    acrServer: acr.outputs.acrServer
    mysqlUserSecretUri: keyvault.outputs.mysqlUserSecretUri
    mysqlPasswordSecretUri: keyvault.outputs.mysqlPasswordSecretUri
    storageShareName: storage.outputs.fileShareName
    storageAccountId: storage.outputs.storageAccountId
    appInsightsKey: appInsights.outputs.instrumentationKey
    userAssignedIdentityId: uami.outputs.uamiId
    acaEnvironmentName: acaEnvironmentName
    containerAppName: containerAppName
  }
}

