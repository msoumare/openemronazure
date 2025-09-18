param location string
param acrServer string
param mysqlUserSecretUri string
param mysqlPasswordSecretUri string
param appInsightsKey string
param acaEnvironmentName string
param containerAppName string
@description('Resource ID of the User Assigned Managed Identity to attach to ACA')
param userAssignedIdentityId string

// OpenEMR configuration now sourced from Key Vault secrets instead of plain parameters
@description('Key Vault secret URI containing the MySQL Flexible Server host name (e.g. myserver.mysql.database.azure.com)')
param mysqlHostSecretUri string
@description('Key Vault secret URI containing the OpenEMR application admin username (OE_USER)')
param oeUserSecretUri string
@description('Key Vault secret URI containing the OpenEMR application admin password (OE_PASS)')
param oePassSecretUri string
@description('Key Vault secret URI containing the timezone string (e.g. UTC or America/New_York)')
param timezoneSecretUri string


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
        // Additional OpenEMR configuration sourced from Key Vault
        {
          name: 'mysql-host'
          keyVaultUrl: mysqlHostSecretUri
          identity: userAssignedIdentityId
        }
        {
          name: 'oe-user'
          keyVaultUrl: oeUserSecretUri
          identity: userAssignedIdentityId
        }
        {
          name: 'oe-pass'
          keyVaultUrl: oePassSecretUri
          identity: userAssignedIdentityId
        }
        {
          name: 'timezone'
          keyVaultUrl: timezoneSecretUri
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
            cpu: 1
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
            // OpenEMR expected env vars (align with local docker-compose.yml)
            {
              name: 'MYSQL_HOST'
              secretRef: 'mysql-host'
            }
            // OpenEMR image expects MYSQL_ROOT_PASS even when using a flexible server admin user; reuse admin password
            {
              name: 'MYSQL_ROOT_PASS'
              secretRef: 'mysql-admin-password'
            }
            // Map MYSQL_USER / MYSQL_PASS to the same admin credentials (or provide separate app user secrets later)
            {
              name: 'MYSQL_USER'
              secretRef: 'mysql-admin-user'
            }
            {
              name: 'MYSQL_PASS'
              secretRef: 'mysql-admin-password'
            }
            {
              name: 'OE_USER'
              value: 'admin'
            }
            {
              name: 'OE_PASS'
              value: 'pass'
            }
            {
              name: 'TZ'
              secretRef: 'timezone'
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
