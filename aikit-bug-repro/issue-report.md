# LocalAI Function Calling Bug Report for AIKit

## Summary
AIKit's embedded LocalAI crashes with a panic when processing OpenAI function calling requests, making it unusable for applications requiring tool/function calling capabilities like HolmesGPT, AutoGen, and similar AI agents.

## Error Details
**Panic Message**: 
```
panic: interface conversion: interface {} is []interface {}, not string
at json_schema.go:65
```

**Context**: This occurs in LocalAI's JSON schema processing when handling OpenAI-compatible function calling requests.

## Environment
- **AIKit Version**: Latest (using LocalAI commit `sha-1a0d06f`)
- **Kubernetes**: Azure Kubernetes Service (AKS)
- **Model**: Llama 3.2 1B (CPU inference)
- **Client**: HolmesGPT with LiteLLM
- **Request Format**: Standard OpenAI `/v1/chat/completions` with `tools` parameter

## Reproduction Steps

### Prerequisites
```bash
git clone https://github.com/your-repo/holmes-aikit-eval
cd holmes-aikit-eval/aikit-bug-repro
```

### 1. Deploy AIKit
```bash
./deploy-aikit.sh
# Wait for model to load (5-10 minutes)
kubectl wait --for=condition=ready pod -l app=llama3-1b --timeout=600s
```

### 2. Test Function Calling (triggers bug)
```bash
./test-function-calling.sh
```

### 3. Observe Panic
```bash
kubectl logs -f deployment/llama3-1b
```

## Expected vs Actual Behavior

### Expected Behavior
LocalAI should process the function calling request and either:
1. Return a proper function call response with `tool_calls`
2. Return an error message if function calling is not supported
3. Gracefully handle malformed requests

### Actual Behavior
LocalAI panics and crashes with:
```
panic: interface conversion: interface {} is []interface {}, not string
```

## Minimal Reproduction Case

The bug can be reproduced with this minimal OpenAI-compatible request:

```json
{
  "model": "llama3.2-1b",
  "messages": [
    {"role": "user", "content": "What is 2+2? Use the calculator."}
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "calculator",
        "description": "Perform calculations", 
        "parameters": {
          "type": "object",
          "properties": {
            "expression": {"type": "string"}
          }
        }
      }
    }
  ]
}
```

## Root Cause Analysis

Based on the error location (`json_schema.go:65`), this appears to be a type assertion bug in LocalAI's JSON schema processing code. The code expects a `string` but receives an `[]interface{}` (slice of interfaces).

This likely occurs when LocalAI processes the `properties` section of function parameters, where it incorrectly assumes certain nested values are strings when they might be arrays or objects.

## Impact

This bug makes AIKit completely unusable for:
- **HolmesGPT**: Kubernetes diagnostic AI that relies heavily on function calling
- **AutoGen**: Multi-agent frameworks requiring tool calling  
- **LangChain**: Applications using OpenAI function calling
- **Custom AI agents**: Any application requiring structured tool calling

## Workaround

We've successfully implemented the same functionality using Ollama as an alternative:
- **Repository**: `../k8s/models/ollama/` 
- **Status**: Full function calling support working with HolmesGPT
- **Deployment**: Uses official Ollama image with OpenAI-compatible API

## Suggested Fix

The issue appears to be in LocalAI's JSON schema processing. Suggested areas to investigate:

1. **Type Safety**: Add proper type checking before interface{} conversions
2. **Schema Validation**: Validate function parameter schemas before processing
3. **Error Handling**: Graceful handling of malformed or unexpected schema formats

## Files Provided

- `deploy-aikit.sh` - AIKit deployment script
- `test-function-calling.sh` - Test script that triggers the bug  
- `minimal-repro.py` - Standalone Python reproduction
- `function-call-request.json` - Exact JSON request causing the panic

## Additional Context

This bug appears to be in the LocalAI dependency rather than AIKit itself. The LocalAI version used by AIKit (`sha-1a0d06f`) may need to be updated to a version that fixes this JSON schema processing issue.

## Priority

**High** - This completely breaks function calling functionality, which is increasingly essential for modern AI applications and agent frameworks.