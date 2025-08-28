#!/bin/bash
# Deploy AIKit CPU Models to AKS using Kaito Workspaces
# This script deploys CPU-optimized models for HolmesGPT evaluation

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Install Helm if not present
if ! command -v helm &> /dev/null; then
    print_message "$YELLOW" "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Add Kaito Helm repository
print_message "$GREEN" "Adding Kaito Helm repository..."
helm repo add kaito https://azure.github.io/kaito
helm repo update

# Install Kaito operator
print_message "$GREEN" "Installing latest Kaito operator..."
helm upgrade --install kaito kaito/kaito \
    --namespace kaito-system \
    --create-namespace \
    --wait

print_message "$GREEN" "Kaito operator installed successfully!"

# Check if operator is running
kubectl get pods -n kaito-system

print_message "$GREEN" "Now deploying CPU models..."

# Deploy CPU-optimized models for evaluation
models=(
    "phi-3-mini-4k-instruct"
    "phi-3-mini-128k-instruct" 
    "llama-2-7b-chat"
)

for model in "${models[@]}"; do
    print_message "$YELLOW" "Deploying $model..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: ${model}
  namespace: default
spec:
  resource:
    instanceType: "Standard_D4as_v4"
    labelSelector:
      matchLabels:
        app: ${model}
  inference:
    preset:
      name: ${model}
      accessMode: public
  nodeCount: 1
EOF

    print_message "$GREEN" "✓ Deployed $model workspace"
done

print_message "$GREEN" "All models deployed! Check status with:"
print_message "$YELLOW" "kubectl get workspaces"
print_message "$YELLOW" "kubectl get pods"