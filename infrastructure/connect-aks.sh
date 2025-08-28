#!/bin/bash
# Script to connect to the deployed AKS cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
SUBSCRIPTION=""

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --subscription SUB   Azure subscription ID or name"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s my-subscription"
    echo "  $0"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_message "$RED" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Resource names
RESOURCE_GROUP="rg-holmes-cpu-evaluation"
CLUSTER_NAME="holmes-aks-evaluation"

print_message "$GREEN" "=== Connecting to HolmesGPT AKS Cluster ==="
print_message "$YELLOW" "Resource Group: $RESOURCE_GROUP"
print_message "$YELLOW" "Cluster Name: $CLUSTER_NAME"

# Set subscription if provided
if [ -n "$SUBSCRIPTION" ]; then
    print_message "$YELLOW" "Setting subscription: $SUBSCRIPTION"
    az account set --subscription "$SUBSCRIPTION"
    if [ $? -ne 0 ]; then
        print_message "$RED" "Error: Failed to set subscription."
        exit 1
    fi
fi

# Display current subscription
CURRENT_SUB=$(az account show --query name -o tsv)
print_message "$YELLOW" "Current Subscription: $CURRENT_SUB"

# Get AKS credentials
print_message "$GREEN" "Getting AKS credentials..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing

if [ $? -eq 0 ]; then
    print_message "$GREEN" "✓ Successfully connected to AKS cluster"
    
    # Test connection
    print_message "$GREEN" "Testing connection..."
    kubectl get nodes
    
    print_message "$GREEN" ""
    print_message "$GREEN" "Cluster info:"
    kubectl cluster-info
    
    print_message "$GREEN" ""
    print_message "$GREEN" "You can now use kubectl to interact with the cluster."
    print_message "$YELLOW" "Example commands:"
    print_message "$YELLOW" "  kubectl get nodes"
    print_message "$YELLOW" "  kubectl get pods --all-namespaces"
    print_message "$YELLOW" "  kubectl get services"
else
    print_message "$RED" "✗ Failed to get AKS credentials"
    exit 1
fi