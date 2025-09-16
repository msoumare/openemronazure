@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name/prefix for resources')
@minLength(3)
@maxLength(12)
param namePrefix string = 'openemr'

@description('MySQL administrator login (do not use reserved words).')
param mysqlAdmin string = 'openemradmin'

@secure()
@description('MySQL administrator password')
param mysqlPassword string

@description('MySQL tier (Flexible Server)')
@allowed([ 'Burstable', 'GeneralPurpose', 'MemoryOptimized' ])
param mysqlSkuTier string = 'Burstable'

@description('MySQL compute SKU name (e.g., Standard_B2s, Standard_D2ds_v5). Keep low for dev.')
param mysqlSkuName string = 'Standard_B1ms'

@description('MySQL version')
@allowed([ '8.0.21', '8.0.28' ])
param mysqlVersion string = '8.0.28'

@description('MySQL storage size in GB')
@minValue(20)
param mysqlStorageGB int = 20

@description('Enable public access with current client IP (dev only). For production configure private networking.')
param allowMyIp bool = true

@description('Optional additional public IPv4 addresses to allow (array of single IPs).')
param allowedIpAddresses array = []

@description('ACR SKU')
@allowed([ 'Basic', 'Standard', 'Premium' ])
param acrSku string = 'Basic'

@description('Container image name (repository) for synthea data job')
param jobImageName string = 'synthea-job'

@description('Run ID tag for container image')
param imageTag string = 'v1'

@description('Number of patients to generate')
@minValue(1)
@maxValue(10000)
param patientCount int = 100

@description('Blob container name to store raw synthea exports')
param dataContainerName string = 'syntheadata'


var acrName = toLower(format('{0}acr', namePrefix))
var storageName = uniqueString(resourceGroup().id, namePrefix, 'st')
var mysqlName = toLower(format('{0}mysql', namePrefix))
var mysqlDbName = 'openemr'
var mysqlFqdn = format('{0}.mysql.database.azure.com', mysqlName)
var containerGroupName = format('{0}-synthea-cg', namePrefix)

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: acrSku }
  properties: {
    adminUserEnabled: true // For simplification; recommend disabling and using ACR tokens or managed identity.
    policies: {
      quarantinePolicy: { status: 'disabled' }
      trustPolicy: { type: 'Notary', status: 'disabled' }
    }
  }
}

// Storage Account for raw data
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// Blob container
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storage.name}/default/${dataContainerName}'
  properties: {
    publicAccess: 'None'
  }
}

// MySQL Flexible Server
resource mysql 'Microsoft.DBforMySQL/flexibleServers@2023-12-01-preview' = {
  name: mysqlName
  location: location
  sku: {
    name: mysqlSkuName
    tier: mysqlSkuTier
  }
  properties: {
    version: mysqlVersion
    administratorLogin: mysqlAdmin
    administratorLoginPassword: mysqlPassword
    storage: {
      storageSizeGB: mysqlStorageGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// MySQL database (child resource)
resource mysqlDb 'Microsoft.DBforMySQL/flexibleServers/databases@2023-12-01-preview' = {
  name: mysqlDbName
  parent: mysql
  properties: {}
}

// Firewall rules if allowMyIp or additional IPs (DEV ONLY)
resource myIpRule 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2023-12-01-preview' = if (allowMyIp) {
  name: 'clientIpRule'
  parent: mysql
  properties: {
    // Placeholder: user should update with real client IP before production use
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Additional fixed IP rules
resource addedRules 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2023-12-01-preview' = [for (ip, i) in allowedIpAddresses: {
  name: 'extra${i}'
  parent: mysql
  properties: {
    startIpAddress: ip
    endIpAddress: ip
  }
}]

// Container Instance to run synthea job (manual start by default)
resource jobContainerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  properties: {
    osType: 'Linux'
    restartPolicy: 'Never'
    imageRegistryCredentials: [
      {
        server: acr.properties.loginServer
        username: listCredentials(acr.id, acr.apiVersion).username
        password: listCredentials(acr.id, acr.apiVersion).passwords[0].value
      }
    ]
    containers: [
      {
        name: 'synthea'
        properties: {
          image: '${acr.properties.loginServer}/${jobImageName}:${imageTag}'
          environmentVariables: [
            { name: 'PATIENT_COUNT', value: string(patientCount) }
            { name: 'MYSQL_HOST', value: mysqlFqdn }
            { name: 'MYSQL_DB', value: mysqlDbName }
            { name: 'MYSQL_USER', value: '${mysqlAdmin}@${mysqlName}' }
            { name: 'BLOB_CONTAINER', value: dataContainerName }
            { name: 'STORAGE_ACCOUNT', value: storage.name }
            { name: 'MYSQL_PASSWORD', secureValue: mysqlPassword }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
        }
      }
    ]
  }
  dependsOn: [ mysqlDb ]
}

output acrLoginServer string = acr.properties.loginServer
output storageAccountName string = storage.name
output mysqlServerName string = mysql.name
output mysqlFqdnOut string = mysqlFqdn
output containerGroupNameOut string = jobContainerGroup.name
output blobContainerName string = dataContainerName
