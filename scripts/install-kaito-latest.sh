#!/bin/bash
# Install Latest Kaito (AIKit) - Manual Installation Method
# Uses the official GitHub releases and kubectl apply method

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message "$GREEN" "=== Installing Latest Kaito (AIKit) on AKS ==="

# Get latest version
LATEST_VERSION=$(curl -s https://api.github.com/repos/Azure/kaito/releases/latest | jq -r '.tag_name')
print_message "$YELLOW" "Latest Kaito version: $LATEST_VERSION"

# Create kaito-system namespace
print_message "$GREEN" "Creating kaito-system namespace..."
kubectl create namespace kaito-system --dry-run=client -o yaml | kubectl apply -f -

# Install Kaito CRDs using the raw GitHub files
print_message "$GREEN" "Installing Kaito CRDs..."
kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/$LATEST_VERSION/charts/kaito/workspace/crds/kaito.sh_workspaces.yaml

# Install GPU provisioner CRDs (needed even for CPU models)
kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/$LATEST_VERSION/charts/kaito/gpu-provisioner/crds/karpenter.sh_machines.yaml
kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/$LATEST_VERSION/charts/kaito/gpu-provisioner/crds/karpenter.sh_machinesets.yaml  
kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/$LATEST_VERSION/charts/kaito/gpu-provisioner/crds/karpenter.sh_nodepools.yaml
kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/$LATEST_VERSION/charts/kaito/gpu-provisioner/crds/karpenter.sh_nodeclaims.yaml

print_message "$GREEN" "CRDs installed successfully!"

# Create a simple Kaito workspace controller deployment
print_message "$GREEN" "Installing Kaito controller..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kaito-workspace-controller
  namespace: kaito-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kaito-workspace-controller
  template:
    metadata:
      labels:
        app: kaito-workspace-controller
    spec:
      containers:
      - name: manager
        image: mcr.microsoft.com/aks/kaito/workspace:$LATEST_VERSION
        ports:
        - containerPort: 8080
        env:
        - name: AZURE_CLIENT_ID
          value: ""
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      serviceAccountName: kaito-workspace-controller
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kaito-workspace-controller
  namespace: kaito-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kaito-workspace-controller
rules:
- apiGroups: ["kaito.sh"]
  resources: ["workspaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kaito-workspace-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kaito-workspace-controller
subjects:
- kind: ServiceAccount
  name: kaito-workspace-controller
  namespace: kaito-system
EOF

print_message "$GREEN" "Waiting for Kaito controller to be ready..."
kubectl rollout status deployment/kaito-workspace-controller -n kaito-system --timeout=300s

print_message "$GREEN" "✅ Kaito installation complete!"
print_message "$YELLOW" "Verify installation:"
print_message "$YELLOW" "kubectl get pods -n kaito-system"
print_message "$YELLOW" "kubectl get crd | grep kaito"