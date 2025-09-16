param location string
param workspaceId string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'openemr-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceId
  }
}
