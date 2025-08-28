#!/bin/bash
# Deployment script for HolmesGPT CPU Model Validation Infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
LOCATION="australiaeast"
SUBSCRIPTION=""
DEPLOYMENT_NAME="holmes-cpu-evaluation-$(date +%Y%m%d-%H%M%S)"

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
    echo "  -l, --location LOC       Azure region [default: eastus]"
    echo "  -n, --name NAME          Deployment name [default: auto-generated]"
    echo "  -v, --validate           Validate templates only, don't deploy"
    echo "  -w, --what-if            Run what-if analysis"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s my-subscription"
    echo "  $0 -s my-subscription -w"
    echo "  $0 -v"
}

# Parse command line arguments
VALIDATE_ONLY=false
WHAT_IF=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -n|--name)
            DEPLOYMENT_NAME="$2"
            shift 2
            ;;
        -v|--validate)
            VALIDATE_ONLY=true
            shift
            ;;
        -w|--what-if)
            WHAT_IF=true
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

# Check if parameters file exists
PARAMS_FILE="infrastructure/parameters.json"
if [ ! -f "$PARAMS_FILE" ]; then
    print_message "$RED" "Error: Parameters file '$PARAMS_FILE' not found."
    exit 1
fi

# Check if main template exists
TEMPLATE_FILE="infrastructure/main.bicep"
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_message "$RED" "Error: Main template file '$TEMPLATE_FILE' not found."
    exit 1
fi

print_message "$GREEN" "=== HolmesGPT CPU Model Evaluation Infrastructure Deployment ==="
print_message "$YELLOW" "Location: $LOCATION"
print_message "$YELLOW" "Deployment Name: $DEPLOYMENT_NAME"

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

# Validate templates
print_message "$GREEN" "Validating Bicep templates..."
az deployment sub validate \
    --name "$DEPLOYMENT_NAME" \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMS_FILE" \
    --no-prompt true

if [ $? -eq 0 ]; then
    print_message "$GREEN" "✓ Template validation successful"
else
    print_message "$RED" "✗ Template validation failed"
    exit 1
fi

# Exit if validate only
if [ "$VALIDATE_ONLY" = true ]; then
    print_message "$GREEN" "Validation complete. Exiting without deployment."
    exit 0
fi

# Run what-if if requested
if [ "$WHAT_IF" = true ]; then
    print_message "$GREEN" "Running what-if analysis..."
    az deployment sub what-if \
        --name "$DEPLOYMENT_NAME" \
        --location "$LOCATION" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "@$PARAMS_FILE" \
        --no-prompt true
    
    echo ""
    read -p "Do you want to proceed with the deployment? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "$YELLOW" "Deployment cancelled."
        exit 0
    fi
fi

# Deploy infrastructure
print_message "$GREEN" "Deploying infrastructure..."
DEPLOYMENT_OUTPUT=$(az deployment sub create \
    --name "$DEPLOYMENT_NAME" \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMS_FILE" \
    --no-prompt true \
    --output json)

if [ $? -eq 0 ]; then
    print_message "$GREEN" "✓ Deployment successful"
    
    # Extract outputs
    print_message "$GREEN" "=== Deployment Outputs ==="
    echo "$DEPLOYMENT_OUTPUT" | jq -r '.properties.outputs | to_entries[] | "\(.key): \(.value.value)"'
    
    # Save outputs to file
    OUTPUT_FILE="outputs/deployment-outputs.json"
    mkdir -p outputs
    echo "$DEPLOYMENT_OUTPUT" | jq '.properties.outputs' > "$OUTPUT_FILE"
    print_message "$GREEN" "Outputs saved to: $OUTPUT_FILE"
else
    print_message "$RED" "✗ Deployment failed"
    exit 1
fi

print_message "$GREEN" "=== Deployment Complete ==="#