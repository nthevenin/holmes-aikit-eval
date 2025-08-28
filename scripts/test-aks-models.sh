#!/bin/bash
# Test AKS-hosted CPU Models for HolmesGPT Evaluation
# This script tests connectivity and model readiness in the AKS cluster

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message "$GREEN" "=== Testing AKS CPU Models ==="

# Check if kubectl is connected to cluster
if ! kubectl cluster-info &>/dev/null; then
    print_message "$RED" "❌ Not connected to AKS cluster. Run ./infrastructure/connect-aks.sh first."
    exit 1
fi

print_message "$GREEN" "✅ Connected to AKS cluster"

# Check Ollama pod status
print_message "$YELLOW" "Checking Ollama pod status..."
if kubectl get pod -l app=ollama-cpu-server | grep -q Running; then
    print_message "$GREEN" "✅ Ollama pod is running"
else
    print_message "$RED" "❌ Ollama pod is not running"
    kubectl get pods -l app=ollama-cpu-server
    exit 1
fi

# Check service endpoints
print_message "$YELLOW" "Checking service endpoints..."
OLLAMA_SERVICE_IP=$(kubectl get svc ollama-cpu-service -o jsonpath='{.spec.clusterIP}')
print_message "$GREEN" "✅ Ollama service IP: $OLLAMA_SERVICE_IP"

# Test connectivity using a test pod
print_message "$YELLOW" "Testing model endpoints..."

# Create a test pod to check connectivity from within the cluster
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: model-test-pod
  namespace: default
spec:
  restartPolicy: Never
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ['sleep', '300']
EOF

# Wait for test pod to be ready
print_message "$YELLOW" "Waiting for test pod..."
kubectl wait --for=condition=ready pod/model-test-pod --timeout=60s

# Test Ollama health endpoint
print_message "$YELLOW" "Testing Ollama health..."
if kubectl exec model-test-pod -- curl -s http://ollama-cpu-service:11434/ | grep -q "Ollama is running"; then
    print_message "$GREEN" "✅ Ollama service is healthy"
else
    print_message "$YELLOW" "⚠️  Ollama may still be starting up"
fi

# Check available models
print_message "$YELLOW" "Checking available models..."
MODELS_OUTPUT=$(kubectl exec model-test-pod -- curl -s http://ollama-cpu-service:11434/api/tags 2>/dev/null || echo "Failed to get models")

if [[ "$MODELS_OUTPUT" == *"tinyllama"* ]]; then
    print_message "$GREEN" "✅ TinyLlama model is available"
else
    print_message "$YELLOW" "⚠️  TinyLlama model may still be downloading"
fi

if [[ "$MODELS_OUTPUT" == *"phi3"* ]]; then
    print_message "$GREEN" "✅ Phi-3 model is available" 
else
    print_message "$YELLOW" "⚠️  Phi-3 model may still be downloading"
fi

# Test a simple inference request
print_message "$YELLOW" "Testing inference request..."
TEST_RESPONSE=$(kubectl exec model-test-pod -- curl -s -X POST http://ollama-cpu-service:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{"model":"tinyllama:latest","prompt":"Hello","stream":false}' 2>/dev/null || echo "Failed")

if [[ "$TEST_RESPONSE" == *"response"* ]]; then
    print_message "$GREEN" "✅ Inference test successful"
else
    print_message "$YELLOW" "⚠️  Inference test failed - models may still be loading"
    print_message "$YELLOW" "Response: $TEST_RESPONSE"
fi

# Clean up test pod
kubectl delete pod model-test-pod --ignore-not-found=true

print_message "$GREEN" "=== AKS Models Test Complete ==="
print_message "$YELLOW" "Models endpoint: http://ollama-cpu-service.default.svc.cluster.local:11434"
print_message "$YELLOW" "Available models will be downloaded in background"
print_message "$YELLOW" "Check logs: kubectl logs -l app=ollama-cpu-server -f"