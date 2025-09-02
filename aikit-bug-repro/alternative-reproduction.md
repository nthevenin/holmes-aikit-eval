# Alternative Ways to Reproduce AIKit LocalAI Bug

Since some environments may have container registry restrictions (like Azure Policy), here are alternative methods to reproduce the LocalAI function calling bug.

## Method 1: Direct LocalAI Testing

If you have access to LocalAI directly (not through AIKit), you can reproduce with:

```bash
# Pull LocalAI image
docker pull quay.io/go-skynet/local-ai:latest

# Run LocalAI with Llama model
docker run -p 8080:8080 -v $PWD/models:/models \
  quay.io/go-skynet/local-ai:latest \
  --models-path=/models --model=llama3.2-1b

# Test function calling (will cause panic)
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @function-call-request.json
```

## Method 2: Build from Source

Clone and build LocalAI to test the specific version used by AIKit:

```bash
git clone https://github.com/go-skynet/LocalAI.git
cd LocalAI
git checkout sha-1a0d06f  # AIKit's version

# Build and run
make build
./local-ai --models-path=./models --model=llama3.2-1b

# Test with function calling request
```

## Method 3: Docker Compose

Use the provided docker-compose.yml for local testing:

```yaml
# docker-compose.yml
version: '3.8'
services:
  localai:
    image: quay.io/go-skynet/local-ai:latest
    ports:
      - "8080:8080"
    volumes:
      - ./models:/models
    command: --models-path=/models --model=llama3.2-1b
```

```bash
docker-compose up -d
# Test with function calling
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @function-call-request.json
```

## Method 4: Minikube/Kind

For local Kubernetes testing:

```bash
# Start minikube
minikube start

# Deploy without registry restrictions  
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: localai-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: localai-test
  template:
    metadata:
      labels:
        app: localai-test
    spec:
      containers:
      - name: localai
        image: quay.io/go-skynet/local-ai:latest
        ports:
        - containerPort: 8080
        command: ["local-ai"]
        args: ["--models-path=/models", "--model=llama3.2-1b"]
EOF

# Port forward and test
kubectl port-forward deployment/localai-test 8080:8080 &
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @function-call-request.json
```

## Method 5: GitHub Codespaces

Use GitHub Codespaces for a clean environment:

1. Fork the AIKit repository
2. Open in Codespaces
3. Modify the Dockerfile to expose LocalAI directly
4. Build and test with function calling

## Expected Results

All methods should reproduce the same panic:
```
panic: interface conversion: interface {} is []interface {}, not string
at json_schema.go:65
```

## Verification

To confirm you've reproduced the bug:

1. **Service Stops Responding**: The LocalAI service will crash and stop responding
2. **Logs Show Panic**: Container/process logs will show the interface conversion panic
3. **Specific Line**: Error occurs at `json_schema.go:65`
4. **Function Calling Context**: Only happens with `tools`/`functions` in the request

## Comparison Test

To verify this is a LocalAI issue and not a general function calling problem, test the same request against:

- **Ollama**: Works perfectly (see `../k8s/models/ollama/`)
- **OpenAI API**: Works perfectly
- **Azure OpenAI**: Works perfectly
- **Other LocalAI versions**: May work if bug is fixed

This confirms the issue is specific to LocalAI's JSON schema processing in the version used by AIKit.