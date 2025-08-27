# HolmesGPT CPU Model Evaluation

This repository contains the infrastructure and evaluation framework for testing CPU-optimized language models with HolmesGPT for Kubernetes diagnostics.

## 🎯 Objective

Validate HolmesGPT with CPU-based models to enable cost-effective Kubernetes diagnostics without requiring GPUs or external API services.

## 📋 Prerequisites

- Azure CLI (`az`)
- kubectl
- Python 3.9+
- Poetry (for HolmesGPT dependencies)
- Docker (optional, for custom model images)
- Ollama (for local model testing)

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Clone this repository
git clone https://github.com/yourusername/holmes-aikit-eval.git
cd holmes-aikit-eval

# Clone HolmesGPT for evaluation framework
git clone https://github.com/robusta-dev/holmesgpt.git

# Install Python dependencies
pip install -r requirements.txt

# Install HolmesGPT dependencies
cd holmesgpt
poetry install --with=dev
cd ..
```

### 2. Deploy Azure Infrastructure

```bash
# Make scripts executable
chmod +x infrastructure/*.sh

# Deploy development environment
./infrastructure/deploy.sh -e dev -s <your-subscription>

# Connect to AKS cluster
./infrastructure/connect-aks.sh -e dev
```

### 3. Setup Models

```bash
# Make setup script executable
chmod +x scripts/setup_models.sh

# Run interactive setup
./scripts/setup_models.sh
```

### 4. Run Evaluations

```bash
# Run evaluation with default configuration
python scripts/run_evaluation.py --config config/evaluation.yaml

# Evaluate specific model
python scripts/run_evaluation.py --config config/evaluation.yaml --model llama2

# Run parallel evaluations
python scripts/run_evaluation.py --config config/evaluation.yaml --parallel 4
```

### 5. Generate Reports

```bash
# Generate comprehensive report
python scripts/generate_report.py results/evaluation_results_*.json

# View report
open reports/evaluation_report_*.html
```

## 📁 Project Structure

```
holmes-aikit-eval/
├── infrastructure/          # Azure Bicep templates and deployment scripts
│   ├── main.bicep          # Main infrastructure template
│   ├── modules/            # Bicep modules for individual resources
│   ├── parameters/         # Environment-specific parameters
│   ├── deploy.sh           # Deployment script
│   ├── cleanup.sh          # Cleanup script
│   └── connect-aks.sh      # AKS connection script
├── scripts/                # Evaluation and setup scripts
│   ├── run_evaluation.py   # Main evaluation script
│   ├── generate_report.py  # Report generation script
│   └── setup_models.sh     # Model setup helper
├── config/                 # Configuration files
│   └── evaluation.yaml     # Evaluation configuration
├── results/                # Evaluation results (auto-created)
├── reports/                # Generated reports (auto-created)
├── holmesgpt/             # HolmesGPT repository (cloned separately)
└── README.md              # This file
```

## 🧪 Evaluation Framework

### Supported Models

#### Ollama Models
- Llama 2 (7B, 13B) - Various quantizations
- Mistral 7B
- Code Llama 7B
- Microsoft Phi-2
- Orca Mini 3B

#### AIKit Models
- Llama 2 Chat 7B
- Mistral 7B Instruct
- Falcon 7B Instruct
- Phi-2

### Evaluation Metrics

- **Pass Rate**: Percentage of tests passed
- **Latency**: Response time (P50, P90, avg)
- **Resource Usage**: CPU and memory consumption
- **Cost Analysis**: Comparison with GPU/API alternatives

### Test Categories

- **Easy Tests**: Regression tests that must pass
- **Medium Tests**: More challenging diagnostic scenarios

## 📊 Understanding Results

### Report Sections

1. **Executive Summary**: High-level findings and recommendations
2. **Model Rankings**: Performance-ordered list of models
3. **Trade-off Analysis**: Performance vs resource usage
4. **Detailed Results**: Per-model metrics and test outcomes
5. **Visualizations**: Charts comparing models

### Key Metrics

- **Pass Rate > 70%**: Model is viable for production
- **Latency < 5s**: Acceptable for interactive diagnostics
- **Memory < 8GB**: Can run on standard nodes

## 🔧 Configuration

### Evaluation Configuration

Edit `config/evaluation.yaml` to:
- Add/remove models
- Adjust iteration counts
- Configure parallel workers
- Set resource monitoring options

### Infrastructure Configuration

Edit `infrastructure/parameters/*.json` to:
- Change Azure regions
- Adjust node sizes
- Modify resource tags
- Configure retention policies

## 📈 Deployment Scenarios

### Development Testing
```bash
./infrastructure/deploy.sh -e dev -s <subscription>
```
- 3 nodes, auto-scaling
- Standard_D8s_v3 instances
- 30-day log retention

### Production Deployment
```bash
./infrastructure/deploy.sh -e prod -s <subscription>
```
- 5 nodes, auto-scaling
- Standard_D16s_v3 instances
- 90-day log retention

## 🚨 Troubleshooting

### Common Issues

1. **Model download failures**
   ```bash
   # Retry with specific model
   ollama pull <model-name>
   ```

2. **AKS connection issues**
   ```bash
   # Re-authenticate
   az login
   ./infrastructure/connect-aks.sh -e dev
   ```

3. **Evaluation failures**
   ```bash
   # Check logs
   tail -f results/*.json
   
   # Run with debug mode
   RUN_LIVE=true pytest -v tests/llm/
   ```

## 📝 Next Steps

1. **Model Fine-tuning**: Fine-tune best performers on K8s-specific data
2. **Optimization**: Implement model quantization and pruning
3. **Integration**: Deploy to AKS integration environment
4. **A/B Testing**: Compare with existing OpenAI/Claude implementation
5. **Production Rollout**: Gradual deployment with monitoring

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run evaluations with your changes
4. Submit a pull request with results

## 📄 License

This project is licensed under the MIT License.

## 🔗 Related Links

- [HolmesGPT Documentation](https://holmesgpt.dev)
- [AIKit Documentation](https://kaito-project.github.io/aikit/)
- [Ollama Documentation](https://ollama.ai)
- [Azure AKS Documentation](https://docs.microsoft.com/azure/aks/)

## 📧 Contact

For questions or support, please open an issue or contact the AKS team.

---

**Note**: This evaluation framework is designed for testing CPU-based models with HolmesGPT. Results may vary based on hardware, model versions, and test data.