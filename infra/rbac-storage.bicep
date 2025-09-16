param principalId string
param storageAccountName string

@description('Built-in role definition ID for Storage File Data SMB Share Contributor')
var smbContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'a7264617-510b-4343-a828-9731dc254ea7'
)

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource smbRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sa.id, principalId, smbContributorRoleId)
  scope: sa
  properties: {
    principalId: principalId
    roleDefinitionId: smbContributorRoleId
    principalType: 'ServicePrincipal'
  }
}
