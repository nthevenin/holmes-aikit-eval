// Storage Account Module for HolmesGPT CPU Model Validation
@description('The name of the storage account')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('The location of the storage account')
param location string

@description('Tags to apply to the storage account')
param tags object

@description('Storage account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS'])
param sku string = 'Standard_LRS'

@description('Container names to create')
param containerNames array = []

@description('Enable blob versioning')
param enableBlobVersioning bool = true

@description('Enable soft delete for blobs')
param enableSoftDelete bool = true

@description('Soft delete retention days')
param softDeleteRetentionDays int = 7

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob Service Configuration
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: enableSoftDelete ? {
      enabled: true
      days: softDeleteRetentionDays
    } : null
    isVersioningEnabled: enableBlobVersioning
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Create containers
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for containerName in containerNames: {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'holmes-cpu-validation'
    }
  }
}]

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output storageAccountKey string = storageAccount.listKeys().keys[0].value
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'