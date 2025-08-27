// Azure Container Registry Module for HolmesGPT CPU Model Validation
@description('The name of the container registry')
@minLength(5)
@maxLength(50)
param registryName string

@description('The location of the container registry')
param location string

@description('Tags to apply to the registry')
param tags object

@description('SKU tier for the registry')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Standard'

@description('Enable admin user')
param adminUserEnabled bool = true

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess
    
    // Enable content trust
    policies: {
      trustPolicy: {
        type: 'Notary'
        status: 'enabled'
      }
      retentionPolicy: sku == 'Premium' ? {
        days: 30
        status: 'enabled'
      } : null
      quarantinePolicy: {
        status: 'disabled'
      }
    }
    
    // Data endpoint for improved performance
    dataEndpointEnabled: sku == 'Premium'
    
    // Network rule set
    networkRuleSet: {
      defaultAction: 'Allow'
    }
    
    // Zone redundancy for Premium SKU
    zoneRedundancy: sku == 'Premium' ? 'Enabled' : 'Disabled'
  }
}

// Outputs
output registryId string = containerRegistry.id
output registryName string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
output adminUsername string = adminUserEnabled ? containerRegistry.listCredentials().username : ''
output adminPassword string = adminUserEnabled ? containerRegistry.listCredentials().passwords[0].value : ''