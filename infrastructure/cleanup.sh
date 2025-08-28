#!/bin/bash
# Cleanup script for HolmesGPT CPU Model Validation Infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
SUBSCRIPTION=""
FORCE=false

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
    echo "  -f, --force              Force deletion without confirmation"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s my-subscription"
    echo "  $0 -s my-subscription -f"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
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

# Resource group name
RESOURCE_GROUP="rg-holmes-cpu-evaluation"

print_message "$GREEN" "=== HolmesGPT CPU Model Evaluation Infrastructure Cleanup ==="
print_message "$YELLOW" "Resource Group: $RESOURCE_GROUP"

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

# Check if resource group exists
RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP")

if [ "$RG_EXISTS" = "false" ]; then
    print_message "$YELLOW" "Resource group '$RESOURCE_GROUP' does not exist. Nothing to cleanup."
    exit 0
fi

# List resources in the resource group
print_message "$GREEN" "Resources to be deleted:"
az resource list --resource-group "$RESOURCE_GROUP" --output table

# Confirmation prompt if not forced
if [ "$FORCE" != true ]; then
    print_message "$RED" "WARNING: This will delete ALL resources in the resource group '$RESOURCE_GROUP'"
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        print_message "$YELLOW" "Cleanup cancelled."
        exit 0
    fi
fi

# Delete resource group
print_message "$GREEN" "Deleting resource group '$RESOURCE_GROUP'..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

print_message "$GREEN" "✓ Resource group deletion initiated."
print_message "$YELLOW" "Note: Resource group deletion is running in the background."
print_message "$YELLOW" "You can check the status with: az group show --name $RESOURCE_GROUP"

print_message "$GREEN" "=== Cleanup Initiated ==="#