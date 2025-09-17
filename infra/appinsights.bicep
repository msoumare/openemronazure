param location string
param workspaceId string
param appInsightsName string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceId
  }
}

output instrumentationKey string = appInsights.properties.InstrumentationKey
