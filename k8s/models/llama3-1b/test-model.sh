#!/bin/bash
set -e

DEPLOYMENT_NAME="llama3-1b"
PORT="8080"

echo "🧪 Testing model deployment: $DEPLOYMENT_NAME"

# Function to cleanup port forward on exit
cleanup() {
    if [ ! -z "$PF_PID" ]; then
        echo "🧹 Stopping port forward..."
        kill $PF_PID 2>/dev/null || true
        wait $PF_PID 2>/dev/null || true
    fi
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Check if deployment exists
if ! kubectl get deployment $DEPLOYMENT_NAME >/dev/null 2>&1; then
    echo "❌ Deployment '$DEPLOYMENT_NAME' not found"
    exit 1
fi

# # Start port forward to service for more stability
# echo "📡 Starting port forward to service/llama3-1b-service..."
# kubectl port-forward service/llama3-1b-service $PORT:8080 &
# PF_PID=$!

# Wait for port forward to be ready
echo "⏳ Waiting for port forward to be ready..."
sleep 10

# Verify the connection is working
echo "🔍 Testing connection..."
for i in {1..5}; do
    if curl -s http://localhost:$PORT/v1/models >/dev/null 2>&1; then
        echo "✅ Connection established"
        break
    fi
    echo "⏳ Waiting for connection... attempt $i/5"
    sleep 2
done

# Test the model
echo "📝 Sending test request..."
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3.2-1b-instruct",
    "messages": [{"role": "user", "content": "What is Kubernetes?"}],
    "max_tokens": 50
  }' | jq '.'

echo ""
echo "🕵️ Testing with HolmesGPT..."

# Navigate to the HolmesGPT directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT/holmesgpt"

# Set environment variables for Holmes
export OPENAI_API_BASE="http://localhost:$PORT/v1"
export OPENAI_API_KEY="not-needed"

# Test with Holmes CLI
echo "📝 Holmes test: What pods are failing?"
poetry run holmes ask "what pods are failing?" --model="openai/llama-3.2-1b-instruct"

echo ""
echo "✅ Test complete!"