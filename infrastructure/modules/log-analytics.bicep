// Log Analytics Workspace Module for HolmesGPT CPU Model Validation
@description('The name of the Log Analytics workspace')
param workspaceName string

@description('The location of the workspace')
param location string

@description('Tags to apply to the workspace')
param tags object

@description('Retention period in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Daily quota in GB')
param dailyQuotaGb int = 5

@description('SKU for the workspace')
@allowed(['PerGB2018', 'Free', 'Standalone', 'PerNode', 'Standard', 'Premium'])
param sku string = 'PerGB2018'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Outputs
output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output customerId string = logAnalyticsWorkspace.properties.customerId
output primarySharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey