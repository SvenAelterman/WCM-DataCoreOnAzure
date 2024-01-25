param namingStructure string
param location string
param abbreviations object

resource logAnalyticsWS 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: replace(namingStructure, '{rtype}', abbreviations['Log Analytics Workspace'])
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}

// Enable a delete lock on this critical resource
resource lock 'Microsoft.Authorization/locks@2017-04-01' = {
  name: '${logAnalyticsWS.name}-lck'
  scope: logAnalyticsWS
  properties: {
    level: 'CanNotDelete'
  }
}

output workspaceName string = logAnalyticsWS.name
output workspaceId string = logAnalyticsWS.id
