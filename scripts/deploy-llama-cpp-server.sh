#!/bin/bash
set -e

echo "🦙 Deploying llama-cpp-python server as AIKit alternative"
echo "This server has stable function calling support for HolmesGPT"

# Check if llama-cpp-python is installed
if ! python -c "import llama_cpp" 2>/dev/null; then
    echo "📦 Installing llama-cpp-python server..."
    pip install 'llama-cpp-python[server]'
fi

# Download Llama 3.2 1B model (same as AIKit used)
MODEL_DIR="/tmp/models"
MODEL_FILE="$MODEL_DIR/Llama-3.2-1B-Instruct-Q4_K_M.gguf"

mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL_FILE" ]; then
    echo "📥 Downloading Llama 3.2 1B Q4_K_M model..."
    curl -L "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf" \
         -o "$MODEL_FILE"
fi

echo "🚀 Starting llama-cpp-python server..."
echo "   Model: Llama-3.2-1B-Instruct-Q4_K_M.gguf"
echo "   Port: 8080"
echo "   Features: Function calling enabled"
echo ""
echo "   Test with: curl http://localhost:8080/v1/models"
echo "   Stop with: Ctrl+C"
echo ""

# Start the server with function calling support
python -m llama_cpp.server \
    --model "$MODEL_FILE" \
    --host 0.0.0.0 \
    --port 8080 \
    --chat_format chatml \
    --n_ctx 4096 \
    --n_threads 4 \
    --verbose