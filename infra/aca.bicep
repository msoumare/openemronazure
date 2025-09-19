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

@description('Azure File share name containing the sites directory contents')
param fileShareName string

// Unique name for managed environment storage
var envStorageName = '${storageAccountName}-${fileShareName}'

// OpenEMR config
@description('Plain MySQL Flexible Server host name (e.g. myserver.mysql.database.azure.com)')
param mysqlHost string

@description('Plain OpenEMR application admin username (OE_USER)')
param oeUser string = 'openemradmin'

@description('Key Vault secret URI containing the OpenEMR application admin password (OE_PASS)')
param oePassSecretUri string

@description('Timezone for OpenEMR')
param timezone string = 'UTC'

@description('Container image reference for OpenEMR (repository[:tag])')
param openEmrImage string = 'openemr/openemr:7.0.3'

// --------------------
// ACA Environment
// --------------------
resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: acaEnvironmentName
  location: location
  properties: {}
}

// --------------------
// Register Azure File share storage
// --------------------
resource envStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: envStorageName
  parent: acaEnv
  properties: {
    azureFile: {
      accountName: storageAccountName
      shareName: fileShareName
      accountKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value
      accessMode: 'ReadWrite'
    }
  }
}

// --------------------
// Container App
// --------------------
resource aca 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  dependsOn: [
    envStorage
  ]
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
        {
          name: 'oe-pass'
          keyVaultUrl: oePassSecretUri
          identity: userAssignedIdentityId
        }
      ]
    }
    template: {
      // Init container seeds the sites directory into Azure Files
      initContainers: [
        {
          name: 'sites-initializer'
          image: openEmrImage
          command: ['/bin/sh']
          args: [
            '-c'
            '''
            if [ ! -f /mnt/sites/.seeded ]; then
              echo "Seeding OpenEMR sites directory..."
              cp -r /var/www/localhost/htdocs/openemr/sites/* /mnt/sites/ || true
              touch /mnt/sites/.seeded
              echo "Sites seeded successfully"
            else
              echo "Sites already initialized, skipping"
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
            cpu: 1
            memory: '2Gi'
          }
          env: [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'MYSQL_HOST'
              value: mysqlHost
            }
            {
              name: 'MYSQL_ROOT_PASS'
              secretRef: 'mysql-admin-password'
            }
            {
              name: 'MYSQL_ROOT_USER'
              secretRef: 'mysql-admin-user'
            }
            {
              name: 'MYSQL_USER'
              secretRef: 'mysql-admin-user'
            }
            {
              name: 'MYSQL_PASS'
              secretRef: 'mysql-admin-password'
            }
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
            {
              name: 'MYSQL_SSL_CA'
              value: '/var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-ca'
            }
            {
              name: 'MYSQL_SSL_MODE'
              value: 'REQUIRED'
            }
          ]
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
          storageType: 'AzureFile'
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
