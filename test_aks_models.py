#!/usr/bin/env python3
"""
Simple test script to validate AKS-hosted CPU models
Tests TinyLlama and Phi-3 models via Ollama API
"""

import requests
import json
import time
from datetime import datetime

def test_ollama_endpoint(endpoint="http://localhost:11434"):
    """Test basic Ollama connectivity"""
    print(f"🔍 Testing Ollama endpoint: {endpoint}")
    
    try:
        response = requests.get(f"{endpoint}/", timeout=10)
        if response.status_code == 200 and "Ollama is running" in response.text:
            print("✅ Ollama is running")
            return True
        else:
            print(f"❌ Ollama endpoint failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False

def get_available_models(endpoint="http://localhost:11434"):
    """Get list of available models"""
    print("\n📋 Checking available models...")
    
    try:
        response = requests.get(f"{endpoint}/api/tags", timeout=10)
        if response.status_code == 200:
            models_data = response.json()
            models = [model['name'] for model in models_data.get('models', [])]
            print(f"✅ Available models: {models}")
            return models
        else:
            print(f"❌ Failed to get models: {response.status_code}")
            return []
    except Exception as e:
        print(f"❌ Error getting models: {e}")
        return []

def test_model_inference(endpoint, model_name, prompt="What is Kubernetes?"):
    """Test model inference with a simple prompt"""
    print(f"\n🧠 Testing {model_name} inference...")
    
    try:
        start_time = time.time()
        
        response = requests.post(
            f"{endpoint}/api/generate",
            json={
                "model": model_name,
                "prompt": prompt,
                "stream": False
            },
            timeout=60
        )
        
        end_time = time.time()
        latency = end_time - start_time
        
        if response.status_code == 200:
            result = response.json()
            response_text = result.get('response', 'No response')
            
            print(f"✅ {model_name} responded in {latency:.2f}s")
            print(f"   Response preview: {response_text[:100]}...")
            
            return {
                "success": True,
                "latency": latency,
                "response_length": len(response_text),
                "model": model_name
            }
        else:
            print(f"❌ {model_name} failed: {response.status_code}")
            return {"success": False, "error": f"HTTP {response.status_code}"}
            
    except Exception as e:
        print(f"❌ {model_name} error: {e}")
        return {"success": False, "error": str(e)}

def run_model_tests(endpoint="http://localhost:11434"):
    """Run comprehensive model tests"""
    print("🚀 Starting AKS CPU Model Tests")
    print("=" * 50)
    
    results = {
        "timestamp": datetime.now().isoformat(),
        "endpoint": endpoint,
        "tests": {}
    }
    
    # Test connectivity
    if not test_ollama_endpoint(endpoint):
        print("❌ Cannot proceed - Ollama not accessible")
        return results
    
    # Get available models
    models = get_available_models(endpoint)
    if not models:
        print("❌ No models available")
        return results
    
    # Test each model
    test_prompts = [
        "What is Kubernetes?",
        "Explain what a pod is in Kubernetes",
        "How do you troubleshoot a failing deployment?"
    ]
    
    for model in models:
        print(f"\n{'='*30}")
        print(f"Testing {model}")
        print(f"{'='*30}")
        
        model_results = []
        
        for i, prompt in enumerate(test_prompts):
            print(f"\n📝 Test {i+1}/3: {prompt[:30]}...")
            result = test_model_inference(endpoint, model, prompt)
            model_results.append(result)
        
        results["tests"][model] = model_results
        
        # Calculate summary stats
        successful_tests = [r for r in model_results if r.get("success")]
        if successful_tests:
            avg_latency = sum(r["latency"] for r in successful_tests) / len(successful_tests)
            print(f"\n📊 {model} Summary:")
            print(f"   Success rate: {len(successful_tests)}/{len(model_results)}")
            print(f"   Average latency: {avg_latency:.2f}s")
    
    return results

def save_results(results, filename="aks_model_test_results.json"):
    """Save test results to file"""
    with open(filename, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\n💾 Results saved to {filename}")

if __name__ == "__main__":
    # Run the tests
    test_results = run_model_tests()
    
    # Save results
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"results/aks/model_validation_{timestamp}.json"
    save_results(test_results, filename)
    
    print("\n" + "="*50)
    print("✅ AKS Model Testing Complete!")
    print("="*50)