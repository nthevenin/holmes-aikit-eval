#!/bin/bash
set -e

SERVICE_NAME="ollama-service"
PORT="11434"
NAMESPACE="${NAMESPACE:-default}"

echo "🧪 Testing Ollama with HolmesGPT"

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
    echo "   Run ./deploy.sh first"
    exit 1
fi

# Start port forward to service
echo "📡 Starting port forward to service/$SERVICE_NAME..."
kubectl port-forward -n $NAMESPACE service/$SERVICE_NAME $PORT:11434 &
PF_PID=$!

# Wait for port forward to be ready
echo "⏳ Waiting for port forward to be ready..."
sleep 10

# Verify the connection is working
echo "🔍 Testing connection..."
for i in {1..5}; do
    if curl -s http://localhost:$PORT/api/tags >/dev/null 2>&1; then
        echo "✅ Connection established"
        break
    fi
    echo "⏳ Waiting for connection... attempt $i/5"
    sleep 3
done

# Test 1: Check available models
echo ""
echo "📝 Test 1: Check available models"
curl -s http://localhost:$PORT/api/tags | jq '.models[] | .name' || echo "Model check failed"

# Test 2: Basic API test with Ollama format
echo ""
echo "📝 Test 2: Basic API test (Ollama format)"
curl -s http://localhost:$PORT/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "prompt": "What is Kubernetes?",
    "stream": false
  }' | jq '.response' || echo "Basic Ollama test failed"

# Test 3: OpenAI-compatible API test
echo ""
echo "📝 Test 3: OpenAI-compatible API test"
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "What is Kubernetes?"}],
    "max_tokens": 50
  }' | jq '.choices[0].message.content' || echo "OpenAI API test failed"

# Test 4: Function calling test
echo ""
echo "📝 Test 4: Function calling test"
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "What is the weather like in London?"}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get the current weather in a location",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {"type": "string", "description": "The city name"}
          },
          "required": ["location"]
        }
      }
    }],
    "tool_choice": "auto",
    "max_tokens": 100
  }' | jq '.choices[0].message' || echo "Function calling test failed"

# Test 5: HolmesGPT integration
echo ""
echo "🕵️ Test 5: HolmesGPT integration test"

# Navigate to HolmesGPT directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT/holmesgpt"

# Set environment variables for Holmes - use Ollama provider (the working solution!)
export OLLAMA_API_BASE="http://localhost:$PORT"

# Test with Holmes CLI using native Ollama provider
echo "📝 Holmes test: Simple Kubernetes query"
echo "📝 Using native Ollama provider with LiteLLM..."

# Ensure model is loaded by making a quick test request first
echo "📝 Warming up model..."
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.2:1b", "messages": [{"role": "user", "content": "Hi"}], "max_tokens": 5}' >/dev/null

# Use ollama/ prefix - this is the working solution!
timeout 60 poetry run holmes ask "what pods are currently running?" --model="ollama/llama3.2:1b" || {
    echo "⚠️ Holmes integration test failed"
    echo "This might be due to function calling compatibility or model naming issues"
    echo ""
    echo "🔧 Manual test of API endpoint:"
    curl -s http://localhost:$PORT/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{
        "model": "llama3.2:1b",
        "messages": [{"role": "user", "content": "Hello"}],
        "max_tokens": 50
      }' | jq '.choices[0].message.content' || echo "API test failed"
}

echo ""
echo "✅ Testing complete!"
echo ""
echo "📊 Results Summary:"
echo "- Models available: Check Test 1 output"
echo "- Basic Ollama API: Check Test 2 output"
echo "- OpenAI compatibility: Check Test 3 output"  
echo "- Function calling: Check Test 4 for tool_calls in response"
echo "- HolmesGPT: Check Test 5 for diagnostic capabilities"
echo ""
echo "🔧 Troubleshooting:"
echo "- If tests fail, check: kubectl logs -n $NAMESPACE deployment/ollama"
echo "- Verify model is loaded: curl http://localhost:$PORT/api/tags"
echo "- Check function calling support for llama3.2:1b model"