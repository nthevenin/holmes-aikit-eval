// Main Bicep template for HolmesGPT CPU Model Validation Infrastructure
targetScope = 'subscription'

@description('The name of the resource group')
param resourceGroupName string

@description('The location of the resource group')
param location string = 'australiaeast'

@description('Environment name')
param environment string = 'evaluation'

@description('Project prefix for resource naming')
param projectPrefix string = 'holmes'

@description('Tags to apply to all resources')
param tags object = {
  project: 'holmes-cpu-validation'
  environment: environment
  managedBy: 'bicep'
}

// Create Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Deploy AKS Cluster (minimal configuration)
module aksCluster 'modules/aks.bicep' = {
  name: 'aks-deployment'
  scope: rg
  params: {
    clusterName: '${projectPrefix}-aks-${environment}'
    location: location
    tags: tags
    nodeCount: 2
    nodeVmSize: 'Standard_D4as_v4' // AMD CPU optimized for evaluation
    environment: environment
    logAnalyticsWorkspaceId: ''
  }
}

// Deploy Container Registry - temporarily disabled
// module containerRegistry 'modules/acr.bicep' = {
//   name: 'acr-deployment'
//   scope: rg
//   params: {
//     registryName: '${projectPrefix}acr${uniqueString(rg.id)}'
//     location: location
//     tags: tags
//     sku: 'Basic'
//   }
// }

// Deploy Storage Account for test results and models
module storageAccount 'modules/storage.bicep' = {
  name: 'storage-deployment'
  scope: rg
  params: {
    storageAccountName: '${projectPrefix}${uniqueString(rg.id)}'
    location: location
    tags: tags
    containerNames: [
      'models'
      'test-results'
      'evaluation-reports'
    ]
  }
}

// Deploy Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics-deployment'
  scope: rg
  params: {
    workspaceName: '${projectPrefix}-logs-${environment}'
    location: location
    tags: tags
    retentionInDays: 30
  }
}

// Outputs
output resourceGroupName string = rg.name
output aksClusterName string = aksCluster.outputs.clusterName
output aksClusterId string = aksCluster.outputs.clusterId
// output acrLoginServer string = containerRegistry.outputs.loginServer
// output acrName string = containerRegistry.outputs.registryName
output storageAccountName string = storageAccount.outputs.storageAccountName
// output storageAccountKey string = storageAccount.outputs.storageAccountKey
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId