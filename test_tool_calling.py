from openai import OpenAI
import json

# Use port 8080 since that's what you're forwarding to
client = OpenAI(base_url="http://localhost:8080/v1", api_key="dummy")

def get_weather(location: str, unit: str):
    return f"Getting the weather for {location} in {unit}..."

tool_functions = {"get_weather": get_weather}

tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get the current weather in a given location",
        "parameters": {
            "type": "object",
            "properties": {
                "location": {"type": "string", "description": "City and state, e.g., 'San Francisco, CA'"},
                "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
            },
            "required": ["location", "unit"]
        }
    }
}]

print("Testing tool calling with OpenAI client...")

try:
    response = client.chat.completions.create(
        model="qwen2.5-coder-7b-instruct",
        messages=[{"role": "user", "content": "What's the weather like in San Francisco?"}],
        tools=tools,
        tool_choice="required"  # Force proper OpenAI tool calling format
    )
    
    print("Full response:")
    print(response.model_dump_json(indent=2))
    
    # Check if tool_calls exists and is not empty
    if response.choices[0].message.tool_calls:
        tool_call = response.choices[0].message.tool_calls[0].function
        print(f"\n✅ Function called: {tool_call.name}")
        print(f"✅ Arguments: {tool_call.arguments}")
        print(f"✅ Result: {tool_functions[tool_call.name](**json.loads(tool_call.arguments))}")
    else:
        print("\n❌ No tool_calls found in response")
        print(f"Response content: {response.choices[0].message.content}")
        
except Exception as e:
    print(f"❌ Error: {e}")