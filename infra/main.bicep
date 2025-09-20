targetScope = 'subscription'

@secure()
param mysqlAdminUser string 
@secure()
param mysqlAdminPassword string
// Additional OpenEMR config (will be stored as Key Vault secrets)
param mysqlHost string
param oeUser string = 'openemradmin'
@secure()
param oePass string
param timezone string = 'UTC'
param location string = 'westeurope'
param resourceGroupName string
param acaEnvironmentName string = 'cae-openemr-dev-westeurope' 
param containerAppName string = 'ca-openemr-dev-westeurope'
param acrName string = 'acropenemrdevwesteurope'
param appInsightsName string = 'appi-openemr-dev-westeurope'
param keyVaultName string = 'kv-openemr-dev-westeu'
param logAnalyticsName string = 'log-openemr-dev-westeurope'
param mySqlName string = 'mysql-openemr-dev-uksouth'
param storageAccountName string = 'saopenemrdevwesteurope'
param userAssignedIdentityName string = 'uai-openemr-dev-westeurope'

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
  // mysqlHost no longer stored in Key Vault
  oePass: oePass
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

// Deploy MySQL 
module mysql './mysql.bicep' = {
  name: 'mysql-deploy'
  scope: rg
  params: {
    location: location
    mySqlName: mySqlName
    mysqlUser: mysqlAdminUser      
    mysqlPassword: mysqlAdminPassword
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
      '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor
    )    
  }
  // dependsOn storage not required; module already references outputs creating implicit dependency
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
    // Build secret URIs inline (avoids outputting secrets from keyvault module)
    mysqlUserSecretUri: keyvault.outputs.mysqlUserSecretUri
    mysqlPasswordSecretUri: keyvault.outputs.mysqlPasswordSecretUri
    mysqlHost: mysqlHost
    oeUser: oeUser
    oePassSecretUri: keyvault.outputs.oePassSecretUri
    timezone: timezone
    appInsightsConnectionString: appInsights.outputs.appInsightsConnectionString
    userAssignedIdentityId: uami.outputs.uamiId
    acaEnvironmentName: acaEnvironmentName
    containerAppName: containerAppName
    storageAccountName: storage.outputs.storageAccountName
    // Use the output tied to the actual share resource so ACA waits for share creation
    fileShareName: storage.outputs.fileShareName
    workspaceId: logs.outputs.workspaceId
  }
}

