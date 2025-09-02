#!/bin/bash
set -e

SERVICE_NAME="aikit-service"
PORT="8080"
NAMESPACE="${NAMESPACE:-default}"

echo "🧪 Testing AIKit Function Calling (this will reproduce the LocalAI bug)"
echo ""

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

# Check if service exists
if ! kubectl get service $SERVICE_NAME -n $NAMESPACE >/dev/null 2>&1; then
    echo "❌ Service '$SERVICE_NAME' not found in namespace '$NAMESPACE'"
    echo "   Run ./deploy-aikit.sh first"
    exit 1
fi

# Start port forward to service
echo "📡 Starting port forward to service/$SERVICE_NAME..."
kubectl port-forward -n $NAMESPACE service/$SERVICE_NAME $PORT:8080 &
PF_PID=$!

# Wait for port forward to be ready
echo "⏳ Waiting for port forward to be ready..."
sleep 10

# Verify the connection is working with a simple request first
echo "🔍 Testing basic connection..."
for i in {1..5}; do
    if curl -s http://localhost:$PORT/ >/dev/null 2>&1; then
        echo "✅ Connection established"
        break
    fi
    echo "⏳ Waiting for connection... attempt $i/5"
    sleep 3
done

# Test 1: Basic health check
echo ""
echo "📝 Test 1: Basic health check"
curl -s http://localhost:$PORT/ || echo "Health check failed"

# Test 2: Simple completion without function calling
echo ""
echo "📝 Test 2: Simple completion (no function calling)"
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }' | jq '.choices[0].message.content' 2>/dev/null || echo "Simple completion test failed"

# Test 3: Function calling test (THIS WILL TRIGGER THE BUG)
echo ""
echo "📝 Test 3: Function calling test (this will cause LocalAI to panic)"
echo "Expected: LocalAI panic with 'interface conversion' error"
echo ""

echo "Sending function calling request..."
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @function-call-request.json \
  > response.json 2>&1

echo "Response saved to response.json"
cat response.json | jq '.' 2>/dev/null || {
    echo "❌ Request failed (likely due to LocalAI panic)"
    echo "Raw response:"
    cat response.json
}

# Test 4: Check if service is still responding (it won't be after the panic)
echo ""
echo "📝 Test 4: Checking if service is still alive after function calling..."
sleep 5
if curl -s http://localhost:$PORT/ >/dev/null 2>&1; then
    echo "✅ Service still responding (unexpected!)"
else
    echo "❌ Service not responding (expected due to LocalAI panic)"
fi

echo ""
echo "🔍 Check AIKit pod logs for the panic:"
echo "   kubectl logs -n $NAMESPACE deployment/aikit-llama3"
echo ""
echo "📊 Expected error in logs:"
echo "   panic: interface conversion: interface {} is []interface {}, not string"
echo "   at json_schema.go:65"