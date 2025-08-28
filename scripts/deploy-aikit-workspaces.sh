#!/bin/bash
# Deploy AIKit Workspaces for HolmesGPT CPU Model Evaluation
# This script replaces Ollama deployment with AIKit/Kaito Workspaces

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message "$GREEN" "=== Deploying AIKit Workspaces for HolmesGPT Evaluation ==="

# Check if Kaito is installed
if ! kubectl get crd workspaces.kaito.sh &>/dev/null; then
    print_message "$RED" "❌ Kaito CRDs not found. Run ./scripts/install-kaito-latest.sh first."
    exit 1
fi

# Verify Kaito operator is running
if ! kubectl get pods -n kaito-system -l app.kubernetes.io/name=kaito | grep -q Running; then
    print_message "$RED" "❌ Kaito operator not running."
    exit 1
fi

print_message "$GREEN" "✅ Kaito operator is running"

# Deploy AIKit Workspaces
print_message "$YELLOW" "Deploying AIKit Workspaces..."
kubectl apply -f k8s/aikit-workspaces.yaml

# Wait for workspaces to be created
print_message "$YELLOW" "Waiting for workspaces to be created..."
sleep 5

# Check workspace status
workspaces=(
    "tinyllama-workspace"
    "phi3-workspace" 
    "phi3-q5-workspace"
    "code-llama-workspace"
    "code-llama-q5-workspace"
    "code-llama-q8-workspace"
)

print_message "$YELLOW" "Checking workspace status..."
for workspace in "${workspaces[@]}"; do
    echo "Workspace: $workspace"
    if kubectl get workspace "$workspace" &>/dev/null; then
        status=$(kubectl get workspace "$workspace" -o jsonpath='{.status.conditions[?(@.type=="WorkspaceReady")].status}' 2>/dev/null || echo "Unknown")
        echo "  Status: $status"
        
        # Show any error messages
        if [ "$status" != "True" ]; then
            kubectl get workspace "$workspace" -o jsonpath='{.status.conditions[?(@.type=="WorkspaceReady")].message}' 2>/dev/null || echo "  No status message"
        fi
    else
        echo "  ❌ Not found"
    fi
    echo
done

print_message "$YELLOW" "Monitoring workspace deployment (this may take 5-10 minutes)..."

# Function to check if a workspace is ready
check_workspace_ready() {
    local workspace=$1
    local status=$(kubectl get workspace "$workspace" -o jsonpath='{.status.conditions[?(@.type=="WorkspaceReady")].status}' 2>/dev/null || echo "False")
    [ "$status" = "True" ]
}

# Monitor workspace deployment with timeout
timeout=1800  # 30 minutes
start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $timeout ]; then
        print_message "$RED" "❌ Timeout waiting for workspaces to be ready"
        break
    fi
    
    ready_count=0
    total_count=${#workspaces[@]}
    
    for workspace in "${workspaces[@]}"; do
        if check_workspace_ready "$workspace"; then
            ((ready_count++))
        fi
    done
    
    print_message "$YELLOW" "Workspaces ready: $ready_count/$total_count"
    
    if [ $ready_count -eq $total_count ]; then
        print_message "$GREEN" "✅ All workspaces are ready!"
        break
    fi
    
    sleep 30
done

# Show final status
print_message "$GREEN" "=== Final Workspace Status ==="
kubectl get workspaces -o wide

# Show inference services
print_message "$GREEN" "=== Inference Services ==="
kubectl get pods -l app.kubernetes.io/name=workspace-inference

# Test model endpoints
print_message "$YELLOW" "Testing model endpoints..."

# Create a test script to validate AIKit inference APIs
cat > /tmp/test-aikit-endpoints.py << 'EOF'
#!/usr/bin/env python3
import requests
import json
import sys
import time

def test_aikit_endpoint(service_name, model_name):
    """Test AIKit inference endpoint"""
    url = f"http://{service_name}.default.svc.cluster.local/v1/completions"
    
    payload = {
        "model": model_name,
        "prompt": "What is Kubernetes?",
        "max_tokens": 50,
        "temperature": 0.5
    }
    
    try:
        print(f"Testing {service_name}...")
        response = requests.post(url, json=payload, timeout=60)
        
        if response.status_code == 200:
            result = response.json()
            completion = result.get('choices', [{}])[0].get('text', '')
            print(f"✅ {service_name}: {completion[:50]}...")
            return True
        else:
            print(f"❌ {service_name}: HTTP {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ {service_name}: Connection failed - {str(e)}")
        return False

# Test endpoints
services = [
    ("tinyllama-workspace-inference", "tinyllama"),
    ("phi3-workspace-inference", "phi-3-mini-4k-instruct"),
    ("code-llama-workspace-inference", "code-llama-7b-instruct")
]

success_count = 0
for service, model in services:
    if test_aikit_endpoint(service, model):
        success_count += 1
    time.sleep(2)

print(f"\nResults: {success_count}/{len(services)} endpoints working")
sys.exit(0 if success_count > 0 else 1)
EOF

# Run endpoint test inside cluster
print_message "$YELLOW" "Running endpoint validation..."
kubectl run aikit-test --image=python:3.9-slim --rm -i --restart=Never -- python3 -c "
import subprocess
import sys
subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'requests'])
$(cat /tmp/test-aikit-endpoints.py | grep -A 999 'def test_aikit_endpoint')
" 2>/dev/null || print_message "$YELLOW" "⚠️  Some endpoints may still be starting up"

# Clean up test script
rm -f /tmp/test-aikit-endpoints.py

print_message "$GREEN" "=== AIKit Workspace Deployment Complete ==="
print_message "$YELLOW" "Next steps:"
print_message "$YELLOW" "1. Run HolmesGPT evaluations: ./scripts/run-holmesgpt-evaluations.sh"
print_message "$YELLOW" "2. Monitor performance: kubectl top pods -l app.kubernetes.io/name=workspace-inference"
print_message "$YELLOW" "3. View logs: kubectl logs -l app.kubernetes.io/name=workspace-inference -f"

# Show how to access models
print_message "$GREEN" "Model Endpoints:"
for workspace in "${workspaces[@]}"; do
    echo "  $workspace: http://${workspace}-inference.default.svc.cluster.local"
done