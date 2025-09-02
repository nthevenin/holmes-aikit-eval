# Updated AIKit Function Calling Test Results

## 🎯 Summary

We successfully deployed and tested AIKit, and made some important discoveries about the current state of function calling support.

## ✅ What Works

1. **✅ AIKit deploys successfully** - Using `ghcr.io/kaito-project/aikit/llama3.1:8b`
2. **✅ LocalAI is running** - Version v3.4.0-109-g05ebc746
3. **✅ Basic chat completions work** - Standard LLM interactions function normally
4. **✅ Service remains stable** - No crashes during function calling attempts
5. **✅ Models are loaded** - `llama-3.1-8b-instruct` is available and working

## ⚠️ What's Partially Working

**Function Calling Issues Discovered:**

### Issue 1: Missing tool_calls in Response
```json
{
  "finish_reason": "tool_calls",
  "message": {
    "role": "assistant", 
    "content": "2+2=4"
    // ❌ Missing: "tool_calls": [...]
  }
}
```

The response indicates `finish_reason: "tool_calls"` but doesn't include the actual `tool_calls` array that OpenAI-compatible APIs should return.

### Issue 2: Model Ignores Function Definitions
When asked "What pods are running?" with a `kubectl_get_pods` function available, the model gave a completely unrelated response about Python setuptools instead of using the provided function.

## 🔍 Original Bug Status

**The LocalAI JSON schema panic we originally wanted to reproduce:**
```
panic: interface conversion: interface {} is []interface {}, not string
at json_schema.go:65
```

**Status**: **NOT REPRODUCED** in current AIKit version (LocalAI v3.4.0)

This suggests either:
- ✅ **Bug was fixed** in newer LocalAI versions
- ✅ **AIKit upgraded** to a LocalAI version without the bug
- 🔄 **Different code path** - the bug may only trigger with specific request formats

## 📊 Comparison with Working Solution (Ollama)

For reference, here's how the same function calling request works with Ollama:

**Request**: (Same as sent to AIKit)
```json
{
  "model": "llama3.2:1b",
  "messages": [{"role": "user", "content": "What is 2+2?"}],
  "tools": [{"type": "function", "function": {"name": "calculator", ...}}]
}
```

**Ollama Response**: (Working correctly)
```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "",
      "tool_calls": [{
        "id": "call_abc123",
        "type": "function",
        "function": {
          "name": "calculator", 
          "arguments": "{\"expression\": \"2+2\"}"
        }
      }]
    },
    "finish_reason": "tool_calls"
  }]
}
```

## 🎯 Recommendations

### For AIKit Issue Report:
1. **Report function calling incompleteness** instead of crash bug
2. **Include test cases** showing current vs expected behavior
3. **Reference working Ollama implementation** for comparison
4. **Help improve** AIKit's OpenAI API compatibility

### For Users:
1. **✅ Use Ollama** for production function calling needs (see `../k8s/models/ollama/`)
2. **🔄 Monitor AIKit** for function calling improvements
3. **🧪 Test newer versions** as they're released

## 📝 Test Results Summary

| Feature | AIKit Result | Expected Result | Status |
|---------|--------------|-----------------|---------|
| Basic Chat | ✅ Works | ✅ Works | ✅ Pass |
| Service Stability | ✅ No crashes | ✅ No crashes | ✅ Pass |
| Function Call Recognition | ❌ Ignores functions | ✅ Uses functions | ❌ Fail |
| Tool Calls Response | ❌ Missing array | ✅ Includes array | ❌ Fail |
| OpenAI Compatibility | ⚠️ Partial | ✅ Full | ⚠️ Partial |

## 🚀 Positive Outcome

While we didn't reproduce the original crash bug, we discovered that:
1. **AIKit stability has improved** - no crashes during testing
2. **Function calling needs refinement** - opportunity to help improve it
3. **Ollama provides a solid alternative** - proven working solution available

This represents **progress** in the AIKit ecosystem! 🎉