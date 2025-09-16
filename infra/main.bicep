targetScope = 'subscription'

@description('Name of the Resource Group to create')
param resourceGroupName string = 'openemr-rg'

@description('Azure region for all resources')
param location string = 'westeurope'

// Create Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// Deploy everything inside RG
module rgDeploy './rg-deploy.bicep' = {
  name: 'rg-deployment'
  scope: rg
  params: {
    location: location
    acrName: 'openemracr'
    mysqlAdminUser: 'openemradmin'
    mysqlAdminPassword: 'ChangeMe123!'
    storageAccountName: 'openemrstorage'
  }
}

