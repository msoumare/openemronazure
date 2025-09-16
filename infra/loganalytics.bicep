param location string

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'openemr-logs'
  location: location
  properties: {
    retentionInDays: 30
  }
}

output workspaceId string = workspace.id
