
param acrName string
param mysqlAdminUser string
param mysqlAdminPassword string
param storageAccountName string

// Deploy ACR
module acr './acr.bicep' = {
  name: 'acr-deploy'
  params: {
    location: location
    acrName: acrName
  }
}

// Deploy MySQL
module mysql './mysql.bicep' = {
  name: 'mysql-deploy'
  params: {
    location: location
    adminUser: mysqlAdminUser
    adminPassword: mysqlAdminPassword
  }
}

// Deploy Storage Account
module storage './storage.bicep' = {
  name: 'storage-deploy'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// Deploy Key Vault with secrets
module keyvault './keyvault.bicep' = {
  name: 'kv-deploy'
  params: {
    location: location
    mysqlConnection: mysql.outputs.connectionString
    storageKey: storage.outputs.storageKey
  }
}

// Deploy Log Analytics
module logs './loganalytics.bicep' = {
  name: 'logs-deploy'
  params: {
    location: location
  }
}

// Deploy Application Insights
module appInsights './appinsights.bicep' = {
  name: 'ai-deploy'
  params: {
    location: location
    workspaceId: logs.outputs.workspaceId
  }
}

// Deploy Container App (OpenEMR)
module aca './aca.bicep' = {
  name: 'aca-deploy'
  params: {
    location: location
    acrServer: acr.outputs.acrServer
    mysqlConnectionSecretUri: keyvault.outputs.mysqlConnectionSecretUri
    storageShareName: storage.outputs.fileShareName
    storageAccountName: storage.outputs.storageAccountName
    appInsightsKey: appInsights.outputs.instrumentationKey
  }
}
