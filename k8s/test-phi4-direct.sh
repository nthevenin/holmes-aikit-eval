#!/bin/bash
set -e

DEPLOYMENT_NAME="aikit-phi4"
PORT="8000"

echo "🔍 Testing Phi-4 model with a direct API call"

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

# Start port forward in background
echo "📡 Starting port forward to deployment/$DEPLOYMENT_NAME..."
kubectl port-forward deployment/$DEPLOYMENT_NAME $PORT:8080 &
PF_PID=$!

# Wait for port forward to be ready
echo "⏳ Waiting for port forward to be ready..."
sleep 5

# Test the model with a simple query
echo "🚀 Sending test query to Phi-4 model..."
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi-4-14b-instruct",
    "messages": [
      {
        "role": "user",
        "content": "Explain the uses for Kubernetes in two sentences."
      }
    ]
  }' | jq .

echo ""
echo "✅ Test complete!"