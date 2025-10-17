#!/bin/bash
set -e

DEPLOYMENT_NAME="aikit-phi4"
PORT="8080"

echo "🕵️ Running HolmesGPT evaluations with Phi-4 model"

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
sleep 10

# Verify connectivity to the model
echo "🔍 Testing connectivity to the model..."
curl -s "http://localhost:$PORT/v1/models" | grep -q "phi-4" && echo "✅ Model API is accessible" || { echo "❌ Cannot access model API"; exit 1; }

# Navigate to the holmes repo (git submodule in root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT/holmesgpt"

# Install dependencies if not already done
if [ ! -d ".venv" ]; then
    echo "📦 Installing HolmesGPT dependencies..."
    poetry install --with=dev
fi

# Set environment variables for local model testing
export RUN_LIVE=true
export MODEL="openai/phi-4-14b-instruct"
export OPENAI_API_BASE="http://localhost:$PORT/v1"
export OPENAI_API_KEY="not-needed"

echo "🚀 Running HolmesGPT easy evaluations..."
echo "   Model: phi-4-14b-instruct via AIKit"
echo "   Endpoint: http://localhost:$PORT/v1"
echo ""

# Run all easy evals - these should always pass
poetry run pytest -m 'llm and easy' --no-cov

echo ""
echo "✅ HolmesGPT evaluation complete!"