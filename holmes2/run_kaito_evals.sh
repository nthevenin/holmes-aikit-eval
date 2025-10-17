#!/bin/bash
# KAITO Holmes Evaluation Script
# Custom script for running Holmes evaluations with KAITO qwen2.5-coder-7b-instruct model

set -e  # Exit on error

# Default values for KAITO setup
DEFAULT_MODELS="qwen2.5-coder-7b-instruct"  # Correct KAITO model name
DEFAULT_MARKERS="easy"  # Start with easy tests
DEFAULT_ITERATIONS="1"

# Parse command line arguments
MODELS="${1:-$DEFAULT_MODELS}"
TEST_MARKERS="${2:-$DEFAULT_MARKERS}"
ITERATIONS="${3:-$DEFAULT_ITERATIONS}"
K_FILTER="${4:-}"  # Optional -k filter for specific tests

# Display help if requested
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [models] [test_markers] [iterations] [k_filter]"
    echo ""
    echo "Run Holmes evaluations with KAITO qwen2.5-coder-7b-instruct model"
    echo ""
    echo "Arguments:"
    echo "  models        Model name (default: $DEFAULT_MODELS)"
    echo "  test_markers  pytest markers (default: $DEFAULT_MARKERS)"
    echo "  iterations    Number of iterations per test (default: $DEFAULT_ITERATIONS)"
    echo "  k_filter      Optional: Filter tests by name pattern (use '' to skip)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run easy tests with defaults"
    echo "  $0 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '01_how_many_pods'  # Specific test"
    echo "  $0 'openai/qwen2.5-coder-7b-instruct' 'easy and kubernetes' 3      # Multiple iterations"
    echo ""
    exit 0
fi

echo "=============================================="
echo "🤖 KAITO Holmes Evaluation"
echo "=============================================="
echo "Models:       $MODELS"
echo "Markers:      $TEST_MARKERS"
echo "Iterations:   $ITERATIONS"
[ -n "$K_FILTER" ] && echo "K Filter:     $K_FILTER"
echo "Max Steps:    7 (KAITO optimized)"
echo "Toolsets:     2 (kubernetes/core + aks/core)"
echo "=============================================="
echo ""

# Verify KAITO endpoint is available
echo "Checking KAITO endpoint..."
if curl -s "http://localhost:8080/v1/models" > /dev/null; then
    echo "✅ KAITO endpoint is accessible"
else
    echo "❌ KAITO endpoint not accessible - make sure port forwarding is active"
    echo "   Run: kubectl port-forward service/qwen2-5-coder-7b-instruct 8080:80"
    exit 1
fi
echo ""

# Check for Kubernetes cluster
if kubectl cluster-info &>/dev/null; then
    echo "✅ Kubernetes cluster is accessible"
else
    echo "⚠️  No Kubernetes cluster found. Tests require a cluster."
    exit 1
fi

# Set KAITO-specific environment variables for Holmes
export HOLMES_OPENAI_BASE_URL="http://localhost:8080/v1"
export HOLMES_OPENAI_API_KEY="fake-key-for-kaito"
export HOLMES_TOOL_CHOICE="required"  # Use required for proper tool calling
export KAITO_CONFIG_PATH="/Users/nickthevenin/holmes-aikit-eval/super-minimal-config.yaml"

# Set standard OpenAI env vars for the evaluation system
export OPENAI_API_KEY="fake-key-for-kaito"
export OPENAI_BASE_URL="http://localhost:8080/v1"
export OPENAI_API_BASE="http://localhost:8080/v1"

# Force refresh toolsets to pick up new config
export REFRESH_TOOLSETS="true"

echo "Environment setup:"
echo "  HOLMES_OPENAI_BASE_URL: $HOLMES_OPENAI_BASE_URL"
echo "  HOLMES_OPENAI_API_KEY: $HOLMES_OPENAI_API_KEY"  
echo "  HOLMES_TOOL_CHOICE: $HOLMES_TOOL_CHOICE"
echo "  KAITO_CONFIG_PATH: $KAITO_CONFIG_PATH"
echo "  OPENAI_API_KEY: $OPENAI_API_KEY"
echo "  OPENAI_BASE_URL: $OPENAI_BASE_URL"
echo ""# Set model environment variables
export MODEL="$MODELS"
export CLASSIFIER_MODEL="$MODELS"
export RUN_LIVE="true"

# Optimize for accuracy with KAITO model
export TEMPERATURE="0.00000001"
export MAX_RETRIES="1"

# Set experiment ID
export EXPERIMENT_ID="kaito-eval-$(date +%Y%m%d-%H%M%S)"
export UPLOAD_DATASET="true"

echo "Environment setup:"
echo "  OPENAI_API_BASE=$OPENAI_API_BASE"
echo "  OPENAI_API_KEY=$OPENAI_API_KEY"
echo "  HOLMES_TOOL_CHOICE=$HOLMES_TOOL_CHOICE"
echo "  MODEL=$MODEL"
echo "  ITERATIONS=$ITERATIONS"
echo "  RUN_LIVE=$RUN_LIVE"
echo "  CLASSIFIER_MODEL=$CLASSIFIER_MODEL"
echo "  EXPERIMENT_ID=$EXPERIMENT_ID"
echo "  KAITO_CONFIG_PATH=$KAITO_CONFIG_PATH"
echo ""

# Build test markers (always prepend "llm and")
TEST_MARKERS="llm and ($TEST_MARKERS)"

# Build pytest command
PYTEST_CMD="poetry run pytest tests/llm/test_ask_holmes.py -m \"$TEST_MARKERS\""
[ -n "$K_FILTER" ] && PYTEST_CMD="$PYTEST_CMD -k \"$K_FILTER\""
PYTEST_CMD="$PYTEST_CMD --no-cov --tb=short -v -s"

echo "Running pytest command:"
echo "  $PYTEST_CMD"
echo ""
echo "=============================================="
echo ""

# Run the tests (with || true to not fail script on test failures)
eval "$PYTEST_CMD" || true

# Show test execution summary
echo ""
echo "==== KAITO Test Execution Summary ===="
echo "Models: $MODELS"
echo "Markers: $TEST_MARKERS"
echo "Iterations: $ITERATIONS"
[ -n "$K_FILTER" ] && echo "K Filter: $K_FILTER"
echo "Max Steps: 7 (KAITO optimized)"
echo "====================================="

# Show generated files
echo ""
echo "Generated files:"
echo "  ✓ Test output displayed above"

echo ""
echo "=============================================="
echo "✅ KAITO evaluation run complete!"
echo ""
echo "Next steps:"
echo "  - Review test output above for results"
echo "  - Run with specific test: $0 '' '' 1 '01_how_many_pods'"
echo "  - Try more iterations: $0 '' '' 3"
echo "=============================================="