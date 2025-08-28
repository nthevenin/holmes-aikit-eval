# HolmesGPT CPU Models on AKS - Production Deployment Guide

This guide provides step-by-step instructions for deploying CPU-based AI models for HolmesGPT on Azure Kubernetes Service (AKS), enabling Kubernetes diagnostics without GPUs or external API dependencies.

## Overview

Deploy Ollama with Phi-3 and TinyLlama CPU models directly in your AKS cluster to provide local AI inference capabilities for HolmesGPT diagnostics.

**Benefits**:
- 🔒 **Data Privacy**: Models run entirely within your cluster
- 💰 **Cost Effective**: No external API calls or GPU requirements  
- 🚀 **Low Latency**: Local inference with sub-30s response times
- 📦 **Self-Contained**: No internet dependencies for inference

## Prerequisites

- Azure CLI installed and logged in
- kubectl configured for your AKS cluster
- Minimum node specs: 4 vCPU, 8GB RAM (Standard_D4as_v4 recommended)
- Poetry installed (for HolmesGPT evaluation)

## Quick Start

### 1. Deploy Infrastructure

```bash
# Clone the repository
git clone https://github.com/your-org/holmes-aikit-eval
cd holmes-aikit-eval

# Deploy AKS cluster (if needed)
chmod +x infrastructure/deploy.sh
./infrastructure/deploy.sh

# Connect to cluster
./infrastructure/connect-aks.sh
```

### 2. Deploy CPU Models

```bash
# Deploy Ollama with CPU models
kubectl apply -f k8s/ollama-cpu-models.yaml

# Wait for deployment
kubectl wait --for=condition=available deployment/ollama-cpu-server --timeout=300s
```

### 3. Verify Models

```bash
# Test model availability
./scripts/test-aks-models.sh

# Expected output:
# ✅ Connected to AKS cluster
# ✅ Ollama pod is running  
# ✅ TinyLlama model is available
# ✅ Phi-3 model is available
# ✅ Inference test successful
```

### 4. Configure HolmesGPT

```yaml
# config/production.yaml
models:
  - name: phi3-aks
    provider: ollama
    endpoint: "http://ollama-cpu-service.default.svc.cluster.local:11434"
    model_name: "phi3:latest"
    description: "Phi-3 3.8B on AKS CPU nodes"
```

## Detailed Deployment

### Infrastructure Components

#### 1. AKS Cluster Configuration
```bicep
// infrastructure/modules/aks.bicep
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  properties: {
    kubernetesVersion: '1.29'
    agentPoolProfiles: [
      {
        name: 'cpunodes'
        count: 1
        vmSize: 'Standard_D4as_v4'  // 4 vCPU, 16GB RAM, AMD
        osType: 'Linux'
        mode: 'System'
      }
    ]
  }
}
```

#### 2. Ollama Deployment
```yaml
# k8s/ollama-cpu-models.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama-cpu-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama-cpu-server
  template:
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        resources:
          requests:
            cpu: 2000m
            memory: 4Gi
          limits:
            cpu: 4000m
            memory: 8Gi
        lifecycle:
          postStart:
            exec:
              command: ["/bin/sh", "-c", "sleep 10 && ollama pull phi3:latest && ollama pull tinyllama:latest"]
```

### Model Selection Guide

#### Phi-3 (Recommended for Production)
- **Size**: 2.2GB (3.8B parameters)
- **Quality**: ✅ High - Accurate technical responses
- **Performance**: ~25-30 seconds response time
- **Use Case**: Primary model for HolmesGPT diagnostics
- **Memory**: ~4GB RAM required

#### TinyLlama (Development/Testing Only)  
- **Size**: 637MB (1B parameters)
- **Quality**: ❌ Low - Inaccurate responses
- **Performance**: ~18 seconds response time
- **Use Case**: Infrastructure testing only
- **Memory**: ~2GB RAM required

### Performance Optimization

#### Resource Sizing
```yaml
# Minimum viable configuration
resources:
  requests:
    cpu: 1000m      # 1 CPU core
    memory: 2Gi     # TinyLlama only
  limits:
    cpu: 2000m
    memory: 4Gi

# Recommended production configuration  
resources:
  requests:
    cpu: 2000m      # 2 CPU cores
    memory: 4Gi     # Phi-3 + overhead
  limits:
    cpu: 4000m      # 4 CPU cores
    memory: 8Gi     # Full node capacity
```

#### Scaling Strategies
```yaml
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ollama-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ollama-cpu-server
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Security Configuration

#### Network Policies
```yaml
# Restrict access to Ollama service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ollama-netpol
spec:
  podSelector:
    matchLabels:
      app: ollama-cpu-server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: holmesgpt
    ports:
    - protocol: TCP
      port: 11434
```

#### RBAC (if needed)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ollama-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ollama-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list"]
```

### Monitoring & Observability

#### Health Checks
```yaml
# Add to deployment container spec
readinessProbe:
  httpGet:
    path: /
    port: 11434
  initialDelaySeconds: 30
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /
    port: 11434
  initialDelaySeconds: 60
  periodSeconds: 30
```

#### Metrics Collection
```bash
# Monitor resource usage
kubectl top pods -l app=ollama-cpu-server

# Check model loading logs
kubectl logs -l app=ollama-cpu-server -f
```

### Troubleshooting

#### Common Issues

**Models not loading**:
```bash
# Check pod status
kubectl describe pod -l app=ollama-cpu-server

# Check model download logs
kubectl logs -l app=ollama-cpu-server --tail=50
```

**API not responding**:
```bash
# Test internal connectivity
kubectl run test-pod --image=curlimages/curl:latest --rm -it -- \
  curl http://ollama-cpu-service:11434/

# Expected: "Ollama is running"
```

**Poor performance**:
```bash
# Check resource usage
kubectl top pod -l app=ollama-cpu-server

# Consider scaling up node or adding replicas
kubectl scale deployment ollama-cpu-server --replicas=2
```

### Cost Optimization

#### Regional Pricing (Monthly Estimates)
- **Australia East**: Standard_D4as_v4 ~$140/month
- **East US**: Standard_D4as_v4 ~$120/month  
- **West Europe**: Standard_D4as_v4 ~$130/month

#### Cost Reduction Strategies
1. **Spot Instances**: 60-80% cost reduction
2. **Reserved Instances**: 20-40% cost reduction
3. **Right-sizing**: Start with D2as_v4 if sufficient
4. **Auto-shutdown**: Scale to zero during off-hours

```bash
# Enable cluster auto-scaling
az aks update \
  --resource-group rg-holmes-cpu-evaluation \
  --name holmes-aks-evaluation \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 3
```

## Integration with HolmesGPT

### Configuration File
```yaml
# ~/.holmesgpt/config.yaml or config/production.yaml
models:
  - provider: ollama
    endpoint: http://ollama-cpu-service.default.svc.cluster.local:11434
    model: phi3:latest
    timeout: 60
    max_retries: 3

# For external access (development)
models:
  - provider: ollama  
    endpoint: http://localhost:11434
    model: phi3:latest
    # Requires: kubectl port-forward svc/ollama-cpu-service 11434:11434
```

### HolmesGPT CLI Usage
```bash
# Install HolmesGPT
pip install holmesgpt

# Run diagnostic with CPU model
holmesgpt ask "What's wrong with my pod?" \
  --config config/production.yaml \
  --model phi3-aks

# Interactive mode
holmesgpt interactive --model phi3-aks
```

### Helm Integration
```yaml
# helm/values.yaml for HolmesGPT
holmesgpt:
  models:
    - name: phi3-aks
      provider: ollama
      endpoint: http://ollama-cpu-service.default.svc.cluster.local:11434
      model: phi3:latest
      
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
```

## Production Checklist

### Pre-Deployment
- [ ] AKS cluster with adequate resources (4+ vCPU, 8+ GB RAM)
- [ ] Network policies configured if required
- [ ] Backup strategy for model data (if customized)
- [ ] Monitoring tools configured

### Post-Deployment
- [ ] Models successfully loaded (run `test-aks-models.sh`)
- [ ] HolmesGPT can connect to Ollama service
- [ ] Resource usage monitoring active
- [ ] Performance benchmarks established
- [ ] Auto-scaling configured (if needed)
- [ ] Disaster recovery plan documented

### Validation Tests
```bash
# 1. Infrastructure test
./scripts/test-aks-models.sh

# 2. Integration test  
kubectl run test-holmesgpt --image=your-holmesgpt:latest --rm -it -- \
  holmesgpt ask "What is a pod?" --model phi3-aks

# 3. Load test (optional)
kubectl run load-test --image=curlimages/curl:latest --rm -it -- \
  curl -X POST http://ollama-cpu-service:11434/api/generate \
  -d '{"model":"phi3:latest","prompt":"Load test"}'
```

## Maintenance

### Updates
```bash
# Update Ollama image
kubectl set image deployment/ollama-cpu-server ollama=ollama/ollama:latest

# Update models
kubectl exec -it $(kubectl get pod -l app=ollama-cpu-server -o jsonpath='{.items[0].metadata.name}') -- \
  ollama pull phi3:latest
```

### Backup & Recovery
```bash
# Backup model data (if using persistent volumes)
kubectl create job backup-models --from=cronjob/backup-ollama-data

# Recovery
kubectl apply -f k8s/ollama-cpu-models.yaml
# Models will be re-downloaded automatically
```

---

## Support & Community

- **Issues**: [GitHub Issues](https://github.com/robusta-dev/holmesgpt/issues)
- **Documentation**: [HolmesGPT Docs](https://docs.holmesgpt.dev)
- **Community**: [Robusta Slack](https://robusta.dev/slack)

---

**Note**: This deployment provides CPU-based inference suitable for development and medium-scale production workloads. For high-throughput production environments, consider GPU-accelerated alternatives or distributed model serving solutions.