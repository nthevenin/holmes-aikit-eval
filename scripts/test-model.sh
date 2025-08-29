#!/bin/bash
set -e

DEPLOYMENT_NAME=${1:-"llama3-1b"}
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

# Start port forward in background
echo "📡 Starting port forward to deployment/$DEPLOYMENT_NAME..."
kubectl port-forward deployment/$DEPLOYMENT_NAME $PORT:8080 &
PF_PID=$!

# Wait for port forward to be ready
echo "⏳ Waiting for port forward to be ready..."
sleep 5

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
echo "✅ Test complete!"