#!/bin/bash
set -e

echo "🦙 Deploying Ollama (using official image only)"
echo "This uses the standard Ollama Docker image with minimal customization"
echo ""

NAMESPACE="${NAMESPACE:-default}"

# Clean up any existing failed deployment
echo "🧹 Cleaning up any existing deployment..."
kubectl delete deployment ollama --ignore-not-found=true -n $NAMESPACE
kubectl delete job ollama-pull-model --ignore-not-found=true -n $NAMESPACE

# Deploy resources
echo "📦 Creating persistent volume claim..."
kubectl apply -f pvc.yaml -n $NAMESPACE

echo "🚀 Deploying Ollama..."
kubectl apply -f deployment.yaml -n $NAMESPACE

echo "🌐 Creating service..."
kubectl apply -f service.yaml -n $NAMESPACE

# Wait for deployment to be ready
echo "⏳ Waiting for Ollama to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/ollama -n $NAMESPACE

# Now download the model
echo "📥 Downloading Llama 3.2 1B model..."
kubectl apply -f pull-model-job.yaml -n $NAMESPACE

echo "⏳ Waiting for model download to complete..."
kubectl wait --for=condition=complete --timeout=600s job/ollama-pull-model -n $NAMESPACE

echo ""
echo "✅ Ollama deployment complete!"
echo ""
echo "📋 Test the deployment:"
echo "   kubectl port-forward -n $NAMESPACE service/ollama-service 11434:11434"
echo "   curl http://localhost:11434/api/tags"
echo ""
echo "🔍 Check status:"
echo "   kubectl get pods -n $NAMESPACE -l app=ollama"
echo "   kubectl logs -n $NAMESPACE deployment/ollama"