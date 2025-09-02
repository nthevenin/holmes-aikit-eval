#!/usr/bin/env python3
"""
Minimal Python reproduction of AIKit LocalAI function calling bug
This can be used independently of HolmesGPT to demonstrate the issue
"""
import requests
import json

def test_aikit_function_calling():
    """
    Minimal test that reproduces the LocalAI panic bug in AIKit
    """
    
    # AIKit endpoint (assumes port-forward is running)
    base_url = "http://localhost:8080"
    
    print("🧪 Minimal AIKit LocalAI Function Calling Bug Reproduction")
    print("=" * 60)
    
    # Test 1: Verify service is alive
    print("\n1. Testing basic connectivity...")
    try:
        response = requests.get(f"{base_url}/readiness", timeout=10)
        print(f"✅ Service responding: {response.status_code}")
    except Exception as e:
        print(f"❌ Service not responding: {e}")
        return False
    
    # Test 2: Simple completion (should work)
    print("\n2. Testing simple completion (baseline)...")
    try:
        payload = {
            "model": "llama3.2:1b",
            "messages": [{"role": "user", "content": "Say hello"}],
            "max_tokens": 20
        }
        response = requests.post(f"{base_url}/v1/chat/completions", 
                               json=payload, timeout=30)
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Simple completion works: {result.get('choices', [{}])[0].get('message', {}).get('content', 'No content')[:50]}...")
        else:
            print(f"❌ Simple completion failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Simple completion error: {e}")
    
    # Test 3: Function calling (will trigger the bug)
    print("\n3. Testing function calling (this will trigger LocalAI panic)...")
    try:
        payload = {
            "model": "llama3.2:1b", 
            "messages": [
                {"role": "user", "content": "What is 2+2? Use the calculator function."}
            ],
            "tools": [
                {
                    "type": "function",
                    "function": {
                        "name": "calculator",
                        "description": "Perform basic math calculations",
                        "parameters": {
                            "type": "object", 
                            "properties": {
                                "expression": {
                                    "type": "string",
                                    "description": "Math expression to evaluate"
                                }
                            },
                            "required": ["expression"]
                        }
                    }
                }
            ],
            "tool_choice": "auto"
        }
        
        print("Sending function calling request...")
        response = requests.post(f"{base_url}/v1/chat/completions",
                               json=payload, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Function calling worked (unexpected!)")
            print(f"Response: {json.dumps(result, indent=2)}")
        else:
            print(f"❌ Function calling failed: {response.status_code}")
            print(f"Response: {response.text}")
            
    except requests.exceptions.ConnectionError as e:
        print("❌ Connection lost during function calling (expected due to LocalAI panic)")
        print(f"Error: {e}")
    except Exception as e:
        print(f"❌ Function calling error: {e}")
    
    # Test 4: Verify service is down after panic
    print("\n4. Testing if service survived the function calling...")
    try:
        response = requests.get(f"{base_url}/readiness", timeout=5)
        print(f"✅ Service still responding: {response.status_code} (unexpected!)")
    except Exception as e:
        print("❌ Service not responding after function calling (expected due to panic)")
    
    print("\n" + "=" * 60)
    print("🔍 If the service stopped responding after step 3, the bug is reproduced!")
    print("📋 Check AIKit pod logs for: 'panic: interface conversion: interface {} is []interface {}, not string'")

if __name__ == "__main__":
    test_aikit_function_calling()