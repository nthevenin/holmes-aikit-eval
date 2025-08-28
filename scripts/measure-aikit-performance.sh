#!/bin/bash
# Measure AIKit-Specific Performance Metrics
# Captures workspace deployment times, API overhead, and scaling characteristics

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message "$GREEN" "=== Measuring AIKit Performance Metrics ==="

results_dir="results/aikit-performance"
mkdir -p "$results_dir"

# Create performance metrics file
performance_file="$results_dir/aikit_performance_metrics.json"
cat > "$performance_file" << EOF
{
  "measurement_date": "$(date -Iseconds)",
  "infrastructure": "AKS Standard_D4as_v4",
  "aikit_version": "$(kubectl get pods -n kaito-system -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo 'unknown')",
  "measurements": {
EOF

workspaces=("tinyllama-workspace" "phi3-workspace" "code-llama-workspace")

# Measure 1: Workspace Creation Time
print_message "$YELLOW" "Measuring workspace creation and startup times..."

workspace_metrics=""
for i, workspace in "${!workspaces[@]}"; do
    print_message "$YELLOW" "Testing $workspace..."
    
    # Delete and recreate workspace to measure cold start
    if kubectl get workspace "$workspace" &>/dev/null; then
        print_message "$YELLOW" "Deleting existing $workspace..."
        kubectl delete workspace "$workspace" --wait=false
        
        # Wait for complete deletion
        while kubectl get workspace "$workspace" &>/dev/null; do
            sleep 2
        done
    fi
    
    # Measure creation time
    start_time=$(date +%s)
    print_message "$YELLOW" "Creating $workspace..."
    
    # Apply just this workspace
    kubectl get -f k8s/aikit-workspaces.yaml | grep -A 20 "name: $workspace" | kubectl apply -f -
    
    # Wait for workspace to be ready
    print_message "$YELLOW" "Waiting for $workspace to be ready..."
    while true; do
        status=$(kubectl get workspace "$workspace" -o jsonpath='{.status.conditions[?(@.type=="WorkspaceReady")].status}' 2>/dev/null || echo "False")
        if [ "$status" = "True" ]; then
            break
        fi
        sleep 10
    done
    
    end_time=$(date +%s)
    creation_time=$((end_time - start_time))
    
    # Measure first inference time
    print_message "$YELLOW" "Measuring first inference latency for $workspace..."
    inference_start=$(date +%s.%3N)
    
    # Test inference endpoint
    model_name=""
    case $workspace in
        "tinyllama-workspace") model_name="tinyllama" ;;
        "phi3-workspace") model_name="phi-3-mini-4k-instruct" ;;
        "code-llama-workspace") model_name="code-llama-7b-instruct" ;;
    esac
    
    # Create test pod to call inference API
    kubectl run aikit-perf-test-$i --image=python:3.9-slim --rm -i --restart=Never --timeout=300s -- python3 -c "
import requests
import time
import sys

def test_inference():
    url = 'http://${workspace}-inference.default.svc.cluster.local/v1/completions'
    payload = {
        'model': '$model_name',
        'prompt': 'What is Kubernetes?',
        'max_tokens': 20,
        'temperature': 0.5
    }
    
    try:
        response = requests.post(url, json=payload, timeout=120)
        return response.status_code == 200
    except:
        return False

# Install requests
import subprocess
subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'requests'], stdout=subprocess.DEVNULL)

# Test inference
if test_inference():
    print('SUCCESS')
    sys.exit(0)
else:
    print('FAILED')
    sys.exit(1)
" > /tmp/inference_test.log 2>&1

    inference_end=$(date +%s.%3N)
    first_inference_time=$(echo "$inference_end - $inference_start" | bc)
    
    # Check if inference succeeded
    if [ $? -eq 0 ]; then
        inference_status="success"
    else
        inference_status="failed"
        first_inference_time="timeout"
    fi
    
    # Measure resource usage
    cpu_usage=$(kubectl top pod -l app.kubernetes.io/name=workspace-inference --no-headers 2>/dev/null | grep "$workspace" | awk '{print $2}' || echo "0m")
    memory_usage=$(kubectl top pod -l app.kubernetes.io/name=workspace-inference --no-headers 2>/dev/null | grep "$workspace" | awk '{print $3}' || echo "0Mi")
    
    # Add to metrics
    if [ $i -gt 0 ]; then
        workspace_metrics+=","
    fi
    
    workspace_metrics+="
    \"$workspace\": {
      \"creation_time_seconds\": $creation_time,
      \"first_inference_time_seconds\": \"$first_inference_time\",
      \"first_inference_status\": \"$inference_status\",
      \"cpu_usage\": \"$cpu_usage\",
      \"memory_usage\": \"$memory_usage\"
    }"
    
    print_message "$GREEN" "✅ $workspace: Created in ${creation_time}s, First inference: ${first_inference_time}s"
    
    # Brief pause between tests
    sleep 30
done

# Measure 2: API Response Times
print_message "$YELLOW" "Measuring API response times..."

# Create latency test script
cat > /tmp/latency_test.py << 'EOF'
import requests
import time
import json
import statistics

def measure_latency(endpoint, model, num_requests=5):
    """Measure API latency"""
    url = f"http://{endpoint}/v1/completions"
    latencies = []
    
    for i in range(num_requests):
        payload = {
            "model": model,
            "prompt": f"Explain Kubernetes pods briefly. Request {i+1}",
            "max_tokens": 30,
            "temperature": 0.5
        }
        
        start = time.time()
        try:
            response = requests.post(url, json=payload, timeout=60)
            if response.status_code == 200:
                latency = time.time() - start
                latencies.append(latency)
        except:
            pass
        
        time.sleep(2)  # Brief pause between requests
    
    if latencies:
        return {
            "min": min(latencies),
            "max": max(latencies), 
            "mean": statistics.mean(latencies),
            "p50": statistics.median(latencies),
            "p90": statistics.quantiles(latencies, n=10)[8] if len(latencies) >= 10 else max(latencies),
            "success_rate": len(latencies) / num_requests
        }
    else:
        return None

# Test endpoints
endpoints = [
    ("tinyllama-workspace-inference.default.svc.cluster.local", "tinyllama"),
    ("phi3-workspace-inference.default.svc.cluster.local", "phi-3-mini-4k-instruct"),
    ("code-llama-workspace-inference.default.svc.cluster.local", "code-llama-7b-instruct")
]

results = {}
for endpoint, model in endpoints:
    print(f"Testing {endpoint}...")
    result = measure_latency(endpoint, model)
    if result:
        results[endpoint.split('.')[0]] = result
    else:
        results[endpoint.split('.')[0]] = {"error": "Failed to get measurements"}

print(json.dumps(results, indent=2))
EOF

# Run latency test
print_message "$YELLOW" "Running latency measurements..."
latency_results=$(kubectl run aikit-latency-test --image=python:3.9-slim --rm -i --restart=Never --timeout=600s -- python3 -c "
import subprocess
import sys
subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'requests'], stdout=subprocess.DEVNULL)
$(cat /tmp/latency_test.py)
" 2>/dev/null || echo '{"error": "Latency test failed"}')

# Measure 3: Scaling Characteristics
print_message "$YELLOW" "Measuring scaling characteristics..."

scaling_metrics=""
for workspace in "${workspaces[@]}"; do
    # Scale down to 0
    print_message "$YELLOW" "Scaling down $workspace..."
    kubectl scale deployment "${workspace}-inference" --replicas=0 --timeout=60s 2>/dev/null || true
    
    # Wait for scale down
    sleep 30
    
    # Measure scale up time
    scale_start=$(date +%s)
    print_message "$YELLOW" "Scaling up $workspace..."
    kubectl scale deployment "${workspace}-inference" --replicas=1 --timeout=300s 2>/dev/null || true
    
    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=workspace-inference --timeout=300s 2>/dev/null || true
    
    scale_end=$(date +%s)
    scale_time=$((scale_end - scale_start))
    
    scaling_metrics+="\"${workspace}\": {\"scale_0_to_1_time_seconds\": $scale_time},"
done

# Remove trailing comma
scaling_metrics=${scaling_metrics%,}

# Compile final metrics
cat >> "$performance_file" << EOF
    "workspace_deployment": {$workspace_metrics
    },
    "api_latency": $latency_results,
    "scaling_performance": {$scaling_metrics}
  }
}
EOF

# Clean up temp files
rm -f /tmp/latency_test.py /tmp/inference_test.log

# Generate summary report
print_message "$YELLOW" "Generating AIKit performance summary..."

cat > "$results_dir/aikit_performance_summary.md" << 'EOF'
# AIKit Performance Analysis

## Workspace Deployment Performance

### Cold Start Times
Measured time from workspace creation to first successful inference:

EOF

# Extract key metrics for summary
python3 -c "
import json
import sys

try:
    with open('$performance_file', 'r') as f:
        data = json.load(f)
    
    print('| Workspace | Creation Time | First Inference | Status |')
    print('|-----------|---------------|----------------|--------|')
    
    for workspace, metrics in data['measurements']['workspace_deployment'].items():
        creation = metrics['creation_time_seconds']
        inference = metrics['first_inference_time_seconds']
        status = metrics['first_inference_status']
        
        status_icon = '✅' if status == 'success' else '❌'
        print(f'| {workspace} | {creation}s | {inference}s | {status_icon} {status} |')
    
    print('\n## API Performance\n')
    
    if 'api_latency' in data['measurements'] and isinstance(data['measurements']['api_latency'], dict):
        print('| Model | Mean Latency | P90 Latency | Success Rate |')
        print('|-------|--------------|-------------|--------------|')
        
        for endpoint, metrics in data['measurements']['api_latency'].items():
            if 'mean' in metrics:
                mean = f\"{metrics['mean']:.2f}s\"
                p90 = f\"{metrics['p90']:.2f}s\"
                success = f\"{metrics['success_rate']*100:.0f}%\"
                print(f'| {endpoint} | {mean} | {p90} | {success} |')
    
    print('\n## Scaling Performance\n')
    print('| Workspace | Scale 0→1 Time |')  
    print('|-----------|----------------|')
    
    for workspace, metrics in data['measurements']['scaling_performance'].items():
        scale_time = metrics['scale_0_to_1_time_seconds']
        print(f'| {workspace} | {scale_time}s |')
        
except Exception as e:
    print(f'Error processing metrics: {e}')
    sys.exit(1)
" >> "$results_dir/aikit_performance_summary.md"

print_message "$GREEN" "=== AIKit Performance Measurement Complete ==="
print_message "$YELLOW" "Results:"
print_message "$YELLOW" "- Raw metrics: $performance_file"
print_message "$YELLOW" "- Summary report: $results_dir/aikit_performance_summary.md"

# Show summary
echo
print_message "$GREEN" "Performance Summary:"
cat "$results_dir/aikit_performance_summary.md"