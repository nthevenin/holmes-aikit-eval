# Ollama for Kubernetes - Llama 3.2 1B CPU Deployment

This deployment provides Ollama with Llama 3.2 1B model for CPU-based inference with OpenAI-compatible function calling support for HolmesGPT.

## Why Ollama?

- ✅ **Native OpenAI API Compatibility**: Built-in `/v1/chat/completions` endpoint
- ✅ **Function Calling Support**: Supports tool calling for compatible models
- ✅ **CPU-First Design**: Automatically runs on CPU without configuration
- ✅ **Easy Model Management**: Simple model pulling and switching
- ✅ **Production Ready**: Stable, widely-used inference server
- ✅ **Persistent Storage**: Models cached across pod restarts

## Quick Deployment

```bash
# Deploy everything
./deploy.sh

# Test the deployment
./test-holmes.sh
```

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐
│    Ollama Server    │    │   Model Pull Job    │
│                     │    │                     │
│ Port: 11434         │◀───│ 1. Wait for Ollama  │
│ API: OpenAI compat  │    │ 2. Pull llama3.2:1b │
│ Uses official image │    │ 3. Complete         │
└─────────────────────┘    └─────────────────────┘
            │                        
            ▼                        
┌─────────────────────┐              
│ Persistent Volume   │              
│ - Model storage     │
│ - 5Gi capacity      │
└─────────────────────┘
```

## Configuration

### Resource Requirements
- **CPU**: 1-2 cores recommended
- **Memory**: 2-4 GB for Llama 3.2 1B
- **Storage**: 5 GB PVC for model persistence
- **Network**: Port 11434 for API access

### Environment Variables
- `OLLAMA_HOST`: Set to "0.0.0.0" for external access
- `OLLAMA_ORIGINS`: Set to "*" to allow CORS
- `OLLAMA_KEEP_ALIVE`: Model timeout (default: "5m")

## API Endpoints

### Native Ollama API
```bash
# List models
curl http://localhost:11434/api/tags

# Generate text
curl http://localhost:11434/api/generate \
  -d '{"model": "llama3.2:1b", "prompt": "What is Kubernetes?"}'
```

### OpenAI-Compatible API
```bash
# Chat completions
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "What is Kubernetes?"}]
  }'

# Function calling
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "Get weather in London"}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get weather for a location",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {"type": "string"}
          }
        }
      }
    }]
  }'
```

## HolmesGPT Integration

```bash
# Set environment variables - use native Ollama provider (working solution!)
export OLLAMA_API_BASE="http://localhost:11434"

# Port forward the service
kubectl port-forward service/ollama-service 11434:11434

# Use with HolmesGPT - use ollama/ prefix for native Ollama provider
poetry run holmes ask "what pods are failing?" --model="ollama/llama3.2:1b"
```

### Alternative Integration Methods

If the native Ollama provider doesn't work, try these alternatives:

```bash
# Method 1: Explicit api_base (requires LiteLLM modification)
# Method 2: OpenAI provider with /v1 endpoint
export OPENAI_API_BASE="http://localhost:11434/v1"
export OPENAI_API_KEY="dummy"
poetry run holmes ask "what pods are failing?" --model="openai/llama3.2:1b"

# Method 3: LiteLLM Proxy (most reliable)
poetry run litellm --model ollama/llama3.2:1b --api_base http://localhost:11434 --port 8000 &
export OPENAI_API_BASE="http://localhost:8000"
poetry run holmes ask "what pods are failing?" --model="llama3.2:1b"
```

## Troubleshooting

### Model Not Loading
```bash
# Check if model downloaded correctly
kubectl exec -it deployment/ollama -- ollama list

# Check initialization logs
kubectl logs deployment/ollama -c download-model
```

### API Not Responding
```bash
# Check pod status
kubectl get pods -l app=ollama

# Check main container logs
kubectl logs deployment/ollama -c ollama

# Verify service connectivity
kubectl port-forward service/ollama-service 11434:11434
curl http://localhost:11434/api/tags
```

### Function Calling Issues
```bash
# Test function calling support
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "Test function calling"}],
    "tools": [{"type": "function", "function": {"name": "test", "parameters": {}}}]
  }'
```

### Performance Issues
- **Slow responses**: Increase CPU allocation or use smaller model
- **Memory issues**: Increase memory limits or use quantized models
- **Cold starts**: Keep models warm with `OLLAMA_KEEP_ALIVE=30m` (default is 30m)

### HolmesGPT Integration Issues
- **Model not found**: Ollama unloads models after inactivity. The test script warms up the model first, but for production use consider:
  - Set `OLLAMA_KEEP_ALIVE` to longer duration (e.g., `2h`)
  - Make periodic keepalive requests to maintain model in memory
  - Or accept first-request warmup time (~10 seconds)

## Alternative Models

Replace `llama3.2:1b` in deployment.yaml with other models:

| Model | Size | Memory | Use Case |
|-------|------|---------|----------|
| `llama3.2:1b` | 1B | ~1.5GB | Fast, small tasks |
| `llama3.2:3b` | 3B | ~2.5GB | Better quality |
| `qwen2.5:0.5b` | 0.5B | ~1GB | Ultra-fast |
| `phi3.5:3.8b` | 3.8B | ~3GB | Code/reasoning |

## Comparison with Other Solutions

| Feature | Ollama | llama-cpp-python | AIKit (broken) |
|---------|--------|------------------|----------------|
| Setup Ease | ✅ Simple | ⚠️ Complex | ✅ Simple |
| Model Management | ✅ Built-in | ❌ Manual | ✅ Built-in |
| OpenAI API | ✅ Native | ✅ Compatible | ✅ Compatible |
| Function Calling | ✅ Supported | ✅ Supported | ❌ Crashes |
| CPU Performance | ✅ Optimized | ✅ Optimized | ✅ Good |
| Documentation | ✅ Excellent | ⚠️ Moderate | ✅ Good |

## References

- [Ollama Documentation](https://ollama.com/)
- [OpenAI API Compatibility](https://ollama.com/blog/openai-compatibility)
- [Kubernetes Deployment Guide](https://ollama.com/blog/ollama-is-now-available-as-an-official-docker-image)
- [HolmesGPT Integration](https://github.com/robusta-dev/holmesgpt)