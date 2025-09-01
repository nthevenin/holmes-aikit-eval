#!/bin/bash
set -e

echo "🚀 Testing LiteLLM Proxy with Ollama"

# Start LiteLLM proxy (runs in background)
echo "📡 Starting LiteLLM proxy..."
cd /home/rob/Documents/github/holmes-aikit-eval/holmesgpt
poetry run litellm --model ollama/llama3.2:1b --api_base http://localhost:11434 --port 8000 &
PROXY_PID=$!

# Wait for proxy to start
sleep 10

# Test with HolmesGPT using the proxy
export OPENAI_API_BASE="http://localhost:8000"
export OPENAI_API_KEY="anything"

echo "🧪 Testing HolmesGPT through LiteLLM proxy..."
timeout 60 poetry run holmes ask "what pods are running?" --model="llama3.2:1b"

# Cleanup
kill $PROXY_PID 2>/dev/null || true