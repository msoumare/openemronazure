param location string
param acrServer string
param mysqlUserSecretUri string
param mysqlPasswordSecretUri string
param storageAccountId string
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
  properties: {
    managedEnvironmentId: acaEnv.id
    configuration: {
      registries: [
        {
          server: acrServer
          identity: userAssignedIdentityId   // ✅ specify the UAMI for ACR pulls
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
      activeRevisionsMode: 'Single'
      ingress: {                            // ✅ add ingress so app is reachable
        external: true
        targetPort: 80
      }
    }
    template: {
      containers: [
        {
          name: 'openemr'
          image: '${acrServer}/openemr:latest'
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
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
          volumeMounts: [
            {
              volumeName: 'sites-volume'
              mountPath: '/var/www/openemr/sites'
            }
          ]
        }
      ]
      volumes: [                            // ✅ must be an array, not `any([...])`
        {
          name: 'sites-volume'
          storageType: 'AzureFile'
          storageName: storageShareName
          storageAccountId: storageAccountId
          identity: userAssignedIdentityId
        }
      ]
      scale: {                              // ✅ optional but recommended
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// Outputs
output containerAppName string = aca.name
