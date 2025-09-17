param location string
param mySqlName string
param mysqlUserSecretUri string
param mysqlPasswordSecretUri string

// Resolve values from Key Vault
var mysqlUser = reference(mysqlUserSecretUri, '2023-07-01', 'Full').value
var mysqlPassword = reference(mysqlPasswordSecretUri, '2023-07-01', 'Full').value

resource mysql 'Microsoft.DBforMySQL/flexibleServers@2023-06-01-preview' = {
  name: mySqlName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: mysqlUser
    administratorLoginPassword: mysqlPassword
    version: '8.0.21'
    storage: {
      storageSizeGB: 32
    }
  }
}

output connectionString string = 'Server=${mysql.properties.fullyQualifiedDomainName};Database=openemr;Uid=${mysqlUser};Pwd=${mysqlPassword};SslMode=Required;'
