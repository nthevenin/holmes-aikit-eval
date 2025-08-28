#!/bin/bash
# Install Latest Kaito (AIKit) on AKS Cluster
# This script installs the latest version of Kaito which includes AIKit functionality

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

# Get latest Kaito version
print_message "$GREEN" "Getting latest Kaito version..."
KAITO_VERSION=$(curl -s -L https://api.github.com/repos/Azure/kaito/releases/latest | jq -r '.tag_name')
print_message "$YELLOW" "Latest version: $KAITO_VERSION"

# Install Kaito CRDs and operator
print_message "$GREEN" "Installing Kaito CRDs..."
kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/main/charts/kaito/workspace/crds/kaito.sh_workspaces.yaml

print_message "$GREEN" "Installing Kaito operator..."
kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/main/charts/kaito/workspace/templates/kaito-workspace.yaml

# Wait for operator to be ready
print_message "$GREEN" "Waiting for Kaito operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/kaito-workspace -n kaito-system || {
    print_message "$YELLOW" "Kaito operator not found in kaito-system, checking other namespaces..."
    kubectl get deployments --all-namespaces | grep kaito || print_message "$RED" "Kaito deployment not found"
}

print_message "$GREEN" "Kaito installation complete!"
print_message "$YELLOW" "You can now create Workspace resources to deploy AI models"