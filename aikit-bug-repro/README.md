# AIKit LocalAI Function Calling Bug Reproduction

This folder contains scripts and configurations to reproduce a critical bug in AIKit's LocalAI integration that prevents function calling from working with HolmesGPT and other applications.

## Bug Summary

**Error**: `panic: interface conversion: interface {} is []interface {}, not string at json_schema.go:65`

**Root Cause**: LocalAI's JSON schema processor crashes when processing OpenAI function calling schemas

**Impact**: Makes AIKit unusable for applications requiring function/tool calling (HolmesGPT, AutoGen, etc.)

## Environment

- **Kubernetes**: AKS (Azure Kubernetes Service)
- **AIKit Version**: Latest (uses LocalAI commit `sha-1a0d06f`)
- **Model**: Llama 3.2 1B (CPU inference)
- **Use Case**: HolmesGPT Kubernetes diagnostics

## Files

- `deploy-aikit.sh` - Deploy AIKit with Llama 3.2 1B
- `test-function-calling.sh` - Test script that triggers the bug
- `minimal-repro.py` - Minimal Python reproduction case
- `function-call-request.json` - Exact request that causes the panic
- `aikit-logs.txt` - Full error logs from AIKit pod
- `issue-report.md` - Complete issue report for AIKit repo

## Quick Reproduction

```bash
# 1. Deploy AIKit
./deploy-aikit.sh

# 2. Wait for model to load (5-10 minutes)
kubectl wait --for=condition=ready pod -l app=aikit-llama3 --timeout=600s

# 3. Test function calling (this will trigger the bug)
./test-function-calling.sh
```

Expected result: LocalAI panic crash with JSON schema conversion error.

## Note on Container Registry Restrictions

If your Kubernetes cluster has container image policies (like Azure Policy) that block `ghcr.io/kaito-project/aikit/*` images, see `alternative-reproduction.md` for other ways to reproduce this bug, including:
- Local Docker testing
- Building from source
- Using unrestricted Kubernetes clusters (kind, minikube)
- GitHub Codespaces

## Working Alternative

For comparison, we've successfully implemented the same functionality using Ollama:
- See `../k8s/models/ollama/` for working solution
- Uses official Ollama image with native OpenAI-compatible API
- Full function calling support working with HolmesGPT