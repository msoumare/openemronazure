param location string
param storageAccountName string

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: {
    SecurityControl: 'Ignore'
  }
  properties: {
    allowSharedKeyAccess: true
  }
}

// Explicitly declare the default file service. Although it is implicitly created, referencing the share
// immediately after storage account creation can occasionally yield a transient 404. Creating this
// intermediate resource introduces a clearer dependency chain and avoids 'The specified resource does not exist.'
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  name: 'default'
  parent: sa
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: 'sites'
  parent: fileService
  properties: {
    shareQuota: 1024
  }
}

output storageAccountId string = sa.id
output storageAccountName string = sa.name
output fileShareName string = share.name
// Convenience output: simple share name (last segment) for volume mounting
// The created share path is <account>/default/sites so this is always 'sites'
output fileShareSimpleName string = 'sites'
