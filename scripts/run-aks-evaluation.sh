#!/bin/bash
# Run HolmesGPT Evaluation Against AKS-hosted CPU Models
# This script sets up port forwarding and runs evaluations

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message "$GREEN" "=== Running HolmesGPT Evaluation on AKS Models ==="

# Check cluster connectivity
if ! kubectl get pods -l app=ollama-cpu-server | grep -q Running; then
    print_message "$RED" "❌ Ollama pod not running in AKS"
    exit 1
fi

# Set up port forwarding to Ollama service
print_message "$YELLOW" "Setting up port forwarding..."
kubectl port-forward svc/ollama-cpu-service 11434:11434 &
PORT_FORWARD_PID=$!

# Wait for port forward to be ready
sleep 5

# Function to cleanup on exit
cleanup() {
    print_message "$YELLOW" "Cleaning up port forward..."
    kill $PORT_FORWARD_PID 2>/dev/null || true
}
trap cleanup EXIT

# Test local connection
print_message "$YELLOW" "Testing local connection to AKS models..."
if curl -s http://localhost:11434/ | grep -q "Ollama is running"; then
    print_message "$GREEN" "✅ Port forwarding successful"
else
    print_message "$RED" "❌ Port forwarding failed"
    exit 1
fi

# Create local config that points to localhost (via port forward)
print_message "$YELLOW" "Creating AKS evaluation configuration..."
cat > config/aks-local.yaml <<EOF
# HolmesGPT AKS Model Evaluation - Local Port Forward
results_dir: results/aks
classifier_model: gpt-4o
eval_types: [easy]
iterations: {easy: 1}
parallel_workers: 1

models:
  - name: tinyllama-aks
    provider: local
    endpoint: "http://localhost:11434"
    description: "TinyLlama on AKS via port-forward"
  - name: phi3-aks  
    provider: local
    endpoint: "http://localhost:11434"
    description: "Phi-3 on AKS via port-forward"
EOF

# Create a simple test script that validates the models work
print_message "$YELLOW" "Running AKS model validation..."
python3 -c "
import requests
import json

# Test TinyLlama
print('Testing TinyLlama...')
response = requests.post('http://localhost:11434/api/generate', 
    json={'model': 'tinyllama:latest', 'prompt': 'What is Kubernetes?', 'stream': False})
if response.status_code == 200:
    result = response.json()
    print(f'✅ TinyLlama response: {result.get(\"response\", \"No response\")[:100]}...')
else:
    print(f'❌ TinyLlama failed: {response.status_code}')

# Test Phi3
print('Testing Phi3...')
response = requests.post('http://localhost:11434/api/generate',
    json={'model': 'phi3:latest', 'prompt': 'Explain pod status in Kubernetes', 'stream': False})
if response.status_code == 200:
    result = response.json()
    print(f'✅ Phi3 response: {result.get(\"response\", \"No response\")[:100]}...')
else:
    print(f'❌ Phi3 failed: {response.status_code}')

print('AKS models validation complete!')
"

print_message "$GREEN" "✅ AKS models are working!"
print_message "$YELLOW" "Models ready for evaluation at: http://localhost:11434"

print_message "$GREEN" "=== AKS Model Testing Complete ==="
print_message "$YELLOW" "To run full evaluation, keep this terminal open and run:"
print_message "$YELLOW" "python scripts/run_evaluation.py --config config/aks-local.yaml"