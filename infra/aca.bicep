param location string
param acrServer string
param mysqlConnectionSecretUri string
param storageShareName string
param storageAccountName string
param appInsightsKey string

resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'openemr-env'
  location: location
}

resource aca 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'openemr-app'
  location: location
  properties: {
    managedEnvironmentId: acaEnv.id
    configuration: {
      registries: [
        {
          server: acrServer
        }
      ]
      secrets: [
        {
          name: 'mysql-conn'
          value: mysqlConnectionSecretUri
        }
      ]
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: 'openemr'
          image: '${acrServer}/openemr:latest'
          env: [
            {
              name: 'MYSQL_CONN'
              secretRef: 'mysql-conn'
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
          storageName: storageShareName
        }
      ]
    }
  }
}
