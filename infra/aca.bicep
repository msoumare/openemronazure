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

// ACA Environment
resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: acaEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
    }
  }
}

// ACA Environment Storage (Azure File share)
resource acaStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: 'mystorage' // name used in volumes below
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
            cpu: '0.5'
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
          storageName: 'mystorage' // must match acaStorage resource
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
