// AKS Cluster Module for HolmesGPT CPU Model Validation
@description('The name of the AKS cluster')
param clusterName string

@description('The location of the AKS cluster')
param location string

@description('Tags to apply to the cluster')
param tags object

@description('Number of nodes in the default node pool')
@minValue(1)
@maxValue(10)
param nodeCount int = 3

@description('VM size for nodes - AMD CPU optimized for inference')
param nodeVmSize string = 'Standard_D4as_v4'

@description('Environment name')
param environment string

@description('Kubernetes version - leave empty for default')
param kubernetesVersion string = ''

@description('Enable monitoring')
param enableMonitoring bool = false

@description('Log Analytics workspace resource ID for monitoring')
param logAnalyticsWorkspaceId string = ''

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion != '' ? kubernetesVersion : null
    dnsPrefix: '${clusterName}-dns'
    
    // Network configuration - simplified
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
    }
    
    // Default node pool - CPU optimized for model inference
    agentPoolProfiles: [
      {
        name: 'cpupool'
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        osSKU: 'Ubuntu'
        mode: 'System'
        enableAutoScaling: true
        minCount: 1
        maxCount: 3
        maxPods: 110
        type: 'VirtualMachineScaleSets'
        nodeTaints: []
        nodeLabels: {
          'workload': 'cpu-inference'
          'environment': environment
        }
        tags: tags
      }
    ]
    
    // Enable addons - minimal configuration
    addonProfiles: {}
    
    // Auto-scaler configuration
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      'expander': 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '10s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'false'
      'skip-nodes-with-system-pods': 'true'
    }
    
    // Security profile - disabled for simplicity
    // securityProfile: {}
  }
}

// Add a dedicated node pool for model inference workloads (optional - temporarily disabled)
resource inferenceNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = if (false) {
  parent: aksCluster
  name: 'inference'
  properties: {
    count: 1
    vmSize: 'Standard_D8as_v4' // AMD CPU for larger models
    osType: 'Linux'
    osSKU: 'Ubuntu'
    mode: 'User'
    enableAutoScaling: true
    minCount: 0  // Can scale to zero
    maxCount: 2  // Reduced max
    maxPods: 30
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'inference=true:NoSchedule'
    ]
    nodeLabels: {
      'workload': 'model-inference'
      'cpu-optimized': 'true'
      'environment': environment
    }
    tags: tags
  }
}

// Outputs
output clusterName string = aksCluster.name
output clusterId string = aksCluster.id
output clusterFqdn string = aksCluster.properties.fqdn
output nodeResourceGroup string = aksCluster.properties.nodeResourceGroup
output principalId string = aksCluster.identity.principalId