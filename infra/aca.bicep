param location string
param acrServer string
param mysqlUserSecretUri string
param mysqlPasswordSecretUri string
param appInsightsKey string
param acaEnvironmentName string
param containerAppName string
@description('Resource ID of the User Assigned Managed Identity to attach to ACA')
param userAssignedIdentityId string


// ACA Environment
resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: acaEnvironmentName
  location: location
  properties: {}
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
  // No external storage; using ephemeral container filesystem only.
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
          image: 'openemr/openemr:7.0.2'
          resources: {
            // Bicep type currently expects int; use 1 vCPU (adjust if fractional becomes supported in your API version)
            cpu: '0.5'
            memory: '2Gi'
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
          // No volume mounts (ephemeral storage). If persistence is needed later, reintroduce Azure File or Blob storage.
        }
      ]
      // No volumes defined.
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

output containerAppName string = aca.name
