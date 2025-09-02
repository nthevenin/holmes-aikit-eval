#!/bin/bash
set -e

echo "🚀 Deploying AIKit with Llama 3.2 1B for bug reproduction"
echo "This deployment will demonstrate the LocalAI function calling bug"
echo ""

NAMESPACE="${NAMESPACE:-default}"

# Clean up any existing deployment
echo "🧹 Cleaning up existing AIKit deployment..."
kubectl delete deployment aikit-llama3 --ignore-not-found=true -n $NAMESPACE
kubectl delete service aikit-service --ignore-not-found=true -n $NAMESPACE

# Deploy AIKit using the deployment.yaml file
echo "📦 Deploying AIKit..."
kubectl apply -f deployment.yaml -n $NAMESPACE

echo "⏳ Waiting for AIKit deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aikit-llama3 -n $NAMESPACE

echo "⏳ Waiting for pod to be ready (model loading can take 5-10 minutes)..."
kubectl wait --for=condition=ready pod -l app=aikit-llama3 --timeout=600s -n $NAMESPACE

echo ""
echo "✅ AIKit deployment complete!"
echo ""
echo "📋 Next steps:"
echo "   ./test-function-calling.sh    # This will trigger the LocalAI bug"
echo ""
echo "🔍 Monitor logs:"
echo "   kubectl logs -f deployment/aikit-llama3 -n $NAMESPACE"