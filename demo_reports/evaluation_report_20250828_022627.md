# HolmesGPT CPU Model Evaluation Report

**Generated:** 2025-08-28 02:26:28

**Evaluation Run:** 20250828_015000

## Executive Summary

- **Total Models Evaluated:** 2
- **Total Tests Run:** 16
- **Average Pass Rate:** 56.7%
- **Best Performing Model:** phi3.5_Q4_K_M
- **Fastest Model:** tinyllama_Q4_K_M

## Model Rankings

### Overall Performance

| Rank | Model | Pass Rate (%) | Avg Latency (s) | Memory (MB) |
|------|-------|--------------|-----------------|-------------|
| 1 | phi3.5_Q4_K_M | 83.3 | 3.10 | 3072 |
| 2 | tinyllama_Q4_K_M | 30.0 | 2.10 | 1536 |

### Easy Tests

| Rank | Model | Pass Rate (%) |
|------|-------|---------------|
| 1 | phi3.5_Q4_K_M | 100.0 |
| 2 | tinyllama_Q4_K_M | 60.0 |

### Medium Tests

| Rank | Model | Pass Rate (%) |
|------|-------|---------------|
| 1 | phi3.5_Q4_K_M | 66.7 |
| 2 | tinyllama_Q4_K_M | 0.0 |

## Detailed Results

### tinyllama_Q4_K_M

**Configuration:**
- Provider: ollama
- Size: 1B
- Quantization: Q4_K_M

**Performance Metrics:**

| Metric | Easy | Medium |
|--------|------|--------|
| Pass Rate | 60.0% | | Pass Rate | 0.0% | 

**Resource Usage:**
- CPU Delta: 30.6%
- Memory Delta: 1536 MB
- Avg Latency: 2.10s

### phi3.5_Q4_K_M

**Configuration:**
- Provider: ollama
- Size: 3.8B
- Quantization: Q4_K_M

**Performance Metrics:**

| Metric | Easy | Medium |
|--------|------|--------|
| Pass Rate | 100.0% | | Pass Rate | 66.7% | 

**Resource Usage:**
- CPU Delta: 46.7%
- Memory Delta: 3072 MB
- Avg Latency: 3.10s


## Trade-off Analysis

### Performance vs Resource Trade-offs

| Model | Pass Rate | Latency | Memory | Overall Score |
|-------|-----------|---------|--------|---------------|
| phi3.5_Q4_K_M | 83.3% | 3.10s | 3072 MB | 42.6 |
| tinyllama_Q4_K_M | 30.0% | 2.10s | 1536 MB | 16.4 |

## Recommendations

Based on the evaluation results, we recommend:

1. **For Maximum Accuracy:** phi3.5_Q4_K_M
   - Best pass rate across all tests
   - Suitable for critical diagnostics where accuracy is paramount

2. **For Minimum Latency:** tinyllama_Q4_K_M
   - Fastest response times
   - Ideal for real-time diagnostics and high-volume scenarios

3. **For Balanced Performance:** phi3.5_Q4_K_M
   - Best trade-off between accuracy and speed
   - Recommended for general production use

### Additional Insights

- **Optimal Quantization:** Q4_K_M provides the best accuracy
- **Model Size Impact:** Larger models generally perform better but require more resources
- **Provider Comparison:** ollama shows best overall performance

## Appendix

### Visualization Charts

![size_vs_performance](charts/size_vs_performance.png)

![resource_usage](charts/resource_usage.png)

![pass_rate_comparison](charts/pass_rate_comparison.png)

![latency_vs_passrate](charts/latency_vs_passrate.png)

![quantization_impact](charts/quantization_impact.png)

![performance_heatmap](charts/performance_heatmap.png)

### Test Configuration

- Classifier Model: gpt-4o
- Evaluation Types: easy, medium
- Iterations: {'easy': 3, 'medium': 2}
