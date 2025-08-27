#!/bin/bash
# Setup script for CPU models (Ollama and AIKit)

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

# Function to setup Ollama
setup_ollama() {
    print_message "$GREEN" "Setting up Ollama models..."
    
    # Check if Ollama is installed
    if ! command -v ollama &> /dev/null; then
        print_message "$YELLOW" "Ollama not found. Installing..."
        curl -fsSL https://ollama.ai/install.sh | sh
    fi
    
    # Pull required models
    models=(
        "llama2:7b-q4_K_M"
        "llama2:7b-q5_K_M"
        "llama2:7b-q8_0"
        "llama2:13b-q4_K_M"
        "mistral:7b-q4_K_M"
        "mistral:7b-q5_K_M"
        "codellama:7b-q4_K_M"
        "phi:2.7b-q4_K_M"
        "orca-mini:3b-q4_K_M"
    )
    
    for model in "${models[@]}"; do
        print_message "$YELLOW" "Pulling $model..."
        ollama pull "$model"
    done
    
    print_message "$GREEN" "Ollama models setup complete!"
}

# Function to setup AIKit models
setup_aikit() {
    print_message "$GREEN" "Setting up AIKit models..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_message "$RED" "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Check if connected to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_message "$RED" "Not connected to Kubernetes cluster. Run ./infrastructure/connect-aks.sh first."
        exit 1
    fi
    
    # Install AIKit operator
    print_message "$YELLOW" "Installing AIKit operator..."
    kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/main/config/crd/bases/kaito.azure.com_workspaces.yaml
    
    # Deploy AIKit models
    models=(
        "llama2-chat-7b"
        "mistral-7b-instruct"
        "falcon-7b-instruct"
        "phi-2"
    )
    
    for model in "${models[@]}"; do
        print_message "$YELLOW" "Deploying $model with AIKit..."
        cat <<EOF | kubectl apply -f -
apiVersion: kaito.azure.com/v1alpha1
kind: Workspace
metadata:
  name: $model
  namespace: default
spec:
  model:
    name: $model
  nodePool:
    instanceType: Standard_D16s_v3
    replicas: 1
  inference:
    enabled: true
    port: 8080
EOF
    done
    
    print_message "$GREEN" "AIKit models deployment initiated!"
    print_message "$YELLOW" "Note: Models may take several minutes to be ready."
    print_message "$YELLOW" "Check status with: kubectl get workspaces"
}

# Main menu
show_menu() {
    echo ""
    print_message "$GREEN" "=== HolmesGPT Model Setup ==="
    echo ""
    echo "1. Setup Ollama models (local)"
    echo "2. Setup AIKit models (Kubernetes)"
    echo "3. Setup both"
    echo "4. Check model status"
    echo "5. Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1)
            setup_ollama
            ;;
        2)
            setup_aikit
            ;;
        3)
            setup_ollama
            setup_aikit
            ;;
        4)
            print_message "$GREEN" "Checking model status..."
            echo ""
            print_message "$YELLOW" "Ollama models:"
            ollama list 2>/dev/null || print_message "$RED" "Ollama not available"
            echo ""
            print_message "$YELLOW" "AIKit models:"
            kubectl get workspaces 2>/dev/null || print_message "$RED" "AIKit not available"
            ;;
        5)
            exit 0
            ;;
        *)
            print_message "$RED" "Invalid option"
            ;;
    esac
}

# Run menu
while true; do
    show_menu
done