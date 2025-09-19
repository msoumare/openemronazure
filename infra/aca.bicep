param location string
param acrServer string
param mysqlUserSecretUri string
param mysqlPasswordSecretUri string
@secure()
param appInsightsConnectionString string
param acaEnvironmentName string
param containerAppName string
@description('Resource ID of the User Assigned Managed Identity to attach to ACA')
param userAssignedIdentityId string
@description('Storage account name hosting Azure File share for persistent OpenEMR sites data')
param storageAccountName string
@description('Azure File share name (simple) containing the sites directory contents')
param fileShareName string

// Name used for the managed environment storage (must be unique within the ACA environment)
var envStorageName = '${storageAccountName}-${fileShareName}'

// OpenEMR configuration now sourced from Key Vault secrets instead of plain parameters
@description('Plain MySQL Flexible Server host name (e.g. myserver.mysql.database.azure.com)')
param mysqlHost string
@description('Plain OpenEMR application admin username (OE_USER)')
param oeUser string = 'openemradmin'
@description('Key Vault secret URI containing the OpenEMR application admin password (OE_PASS)')
param oePassSecretUri string
@description('Plain timezone value (e.g. UTC or America/New_York)')
param timezone string = 'UTC'

@description('Container image reference for OpenEMR (repository[:tag])')
param openEmrImage string = 'openemr/openemr:7.0.3'


// ACA Environment
resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: acaEnvironmentName
  location: location
  properties: {}
}

// Register Azure File share as managed environment storage so it can be mounted by the Container App
resource envStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: envStorageName
  parent: acaEnv
  properties: {
    azureFile: {
      accountName: storageAccountName
      shareName: fileShareName
    // Retrieve storage account key directly. If stricter secrecy needed, reintroduce Key Vault indirection.
    accountKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value
      accessMode: 'ReadWrite'
    }
  }
} 


// Container App
resource aca 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  // Persistent Azure File storage for OpenEMR sites data is registered via envStorage above.
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
        // mysql-host no longer stored as secret
        // oe-user no longer stored as a secret
        {
          name: 'oe-pass'
          keyVaultUrl: oePassSecretUri
          identity: userAssignedIdentityId
        }
        // timezone no longer stored as a secret; using direct env value
      ]
    }
    template: {
      // Init container seeds the Azure File share with the packaged OpenEMR "sites" skeleton
      // Strategy: mount the persistent volume at an alternate path so the original image path is still visible.
      // A sentinel file (.seeded) prevents redundant full copies on restarts / additional replicas.
      initContainers: [
        {
          name: 'sites-initializer'
          image: openEmrImage
          command: ['/bin/sh']
          args: [
            '-c'
            '''
            if [ ! -f /mnt/sites/.seeded ]; then
              echo "Initializing sites structure..."
              
              # Create necessary directories
              mkdir -p /mnt/sites/default
              
              touch /mnt/sites/.seeded
              echo "Sites structure initialized"
            else
              echo "Sites already seeded, skipping initialization"
            fi
            '''
          ]
          volumeMounts: [
            {
              volumeName: 'sitesdata'
              mountPath: '/mnt/sites'
            }
          ]
        }
      ]
      containers: [
        {
          name: 'openemr'
          image: openEmrImage
          resources: {
            // Bicep type currently expects int; use 1 vCPU (adjust if fractional becomes supported in your API version)
            cpu: 1
            memory: '2Gi'
          }
          env: [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            // OpenEMR required env vars (from official documentation)
            {
              name: 'MYSQL_HOST'
              value: mysqlHost
            }
            {
              name: 'MYSQL_ROOT_PASS'
              secretRef: 'mysql-admin-password'
            }
            // For Azure MySQL Flexible Server, set the admin user as root user
            // since Azure doesn't provide a traditional root account
            {
              name: 'MYSQL_ROOT_USER'
              secretRef: 'mysql-admin-user'
            }
            // Optional OpenEMR env vars (will use defaults if not provided)
            {
              name: 'MYSQL_USER'
              secretRef: 'mysql-admin-user'
            }
            {
              name: 'MYSQL_PASS'
              secretRef: 'mysql-admin-password'
            }
            // Explicitly specify the database name since it's pre-created
            {
              name: 'MYSQL_DATABASE'
              value: 'openemr'
            }
            {
              name: 'OE_USER'
              value: oeUser
            }
            {
              name: 'OE_PASS'
              secretRef: 'oe-pass'
            }
            {
              name: 'TZ'
              value: timezone
            }
            // MySQL SSL configuration for Azure MySQL Flexible Server
            {
              name: 'MYSQL_SSL_CA'
              value: '/var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-ca'
            }
            {
              name: 'MYSQL_SSL_MODE'
              value: 'REQUIRED'
            }
          ]
          // Persistent volume mount backing /sites (Azure File share) to retain instance configuration & uploaded data.
          volumeMounts: [
            {
              volumeName: 'sitesdata'
              mountPath: '/var/www/localhost/htdocs/openemr/sites'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'sitesdata'
          // Reference the actual managed environment storage resource name (creates dependency)
          storageName: envStorage.name
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
