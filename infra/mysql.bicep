param location string
param mySqlName string
@secure()
param mysqlUser string

@secure()
param mysqlPassword string


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
