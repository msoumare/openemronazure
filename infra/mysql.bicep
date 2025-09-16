param location string
param adminUser string
@secure()
param adminPassword string

resource mysql 'Microsoft.DBforMySQL/flexibleServers@2023-06-01-preview' = {
  name: 'openemr-mysql'
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: adminUser
    administratorLoginPassword: adminPassword
    version: '8.0.21'
    storage: {
      storageSizeGB: 32
    }
  }
}

output connectionString string = 'Server=${mysql.properties.fullyQualifiedDomainName};Database=openemr;Uid=${adminUser};Pwd=${adminPassword};SslMode=Required;'
