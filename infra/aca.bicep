param location string
param acrServer string
param mysqlUserSecretUri string
param mysqlPasswordSecretUri string
param storageAccountId string
param storageAccountName string
param storageShareName string
param appInsightsKey string
param acaEnvironmentName string
param containerAppName string
@description('Resource ID of the User Assigned Managed Identity to attach to ACA')
param userAssignedIdentityId string

@description('Name of the managed environment storage (used in volume mounts). Change only if you need a new storage binding.')
param acaStorageName string = 'mystorage'

@description('Set to true only on the first deployment that should create the managed environment storage. After it exists, set to false to avoid update limitation (only accountKey can be updated).')
param createAcaStorage bool = true

// ACA Environment
resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: acaEnvironmentName
  location: location
  properties: {}
}

// ACA Environment Storage (Azure File share)
// Managed Environment Storage (can only be created once; subsequent deployments must not attempt to modify except accountKey)
resource acaStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = if (createAcaStorage) {
  name: acaStorageName
  parent: acaEnv
  properties: {
    azureFile: {
      accountName: storageAccountName
      shareName: storageShareName
      accessMode: 'ReadWrite'
      accountKey: listKeys(storageAccountId, '2022-09-01').keys[0].value
    }
  }
}

// Container App
resource aca 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  // Ensure storage (if being created) is deployed before container app. Safe even if conditional resource not deployed.
  dependsOn: [
    acaStorage
  ]
  properties: {
    managedEnvironmentId: acaEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
      registries: [
        {
          server: acrServer
          identity: userAssignedIdentityId
        }
      ]
      secrets: [
        {
          name: 'mysql-admin-user'
          keyVaultUrl: mysqlUserSecretUri
          identity: userAssignedIdentityId
        }
        {
          name: 'mysql-admin-password'
          keyVaultUrl: mysqlPasswordSecretUri
          identity: userAssignedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'openemr'
          image: '${acrServer}/openemr:latest'
          resources: {
            // Bicep type currently expects int; use 1 vCPU (adjust if fractional becomes supported in your API version)
            cpu: 1
            memory: '1Gi'
          }
          env: [
            {
              name: 'MYSQL_ADMIN_USER'
              secretRef: 'mysql-admin-user'
            }
            {
              name: 'MYSQL_ADMIN_PASSWORD'
              secretRef: 'mysql-admin-password'
            }
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: appInsightsKey
            }
          ]
          volumeMounts: [
            {
              volumeName: 'sites-volume'
              mountPath: '/var/www/openemr/sites'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'sites-volume'
          storageType: 'AzureFile'
          storageName: acaStorageName // must match the managed environment storage name
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

output containerAppName string = aca.name
