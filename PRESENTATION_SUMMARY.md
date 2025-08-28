# Executive Presentation: CPU-Based AI for K8s Diagnostics

## Slide 1: Title

### **CPU-Based AI for Kubernetes Diagnostics on AKS**

**HolmesGPT Integration - Performance Validation**

*August 2025*

---

## Slide 2: Test Results

### **Model Performance Validation**

| Metric | Phi-3 | TinyLlama |
|--------|-------|-----------|
| **Accuracy** | 85% ✅ | 45% ❌ |
| **Response Time** | 25-30s | 18s |
| **Memory Usage** | 3.5GB | 1.5GB |
| **Production Ready** | Yes ✅ | No ❌ |

### **Key Finding**: Phi-3 delivers production-quality diagnostics on CPU infrastructure

![Performance Comparison](demo_reports/charts/pass_rate_comparison.png)

---

## Slide 3: Technical Validation

### **Test Categories & Results**

| Test Type | Phi-3 Pass Rate |
|-----------|-----------------|
| Pod Diagnostics | 90% |
| Service Discovery | 85% |
| Resource Analysis | 80% |
| Log Analysis | 85% |
| **Overall** | **85%** |

### **Resource Usage**
- CPU: 45% during inference
- Memory: 3.5GB steady state
- Node: Standard_D4as_v4 (4 vCPU, 16GB RAM)

![Resource Usage](demo_reports/charts/resource_usage.png)

---

## Slide 4: Performance Analysis

### **Response Time Distribution**
- p50: 25 seconds
- p95: 30 seconds
- p99: 35 seconds

### **Token Generation**
- Rate: 35 tokens/second
- Consistent across test scenarios

![Latency Analysis](demo_reports/charts/latency_vs_passrate.png)

---

## Slide 5: Recommendation

### **Deployment Decision**

**✅ DEPLOY** Phi-3 on AKS for production use

### **Implementation**

```yaml
Model: Phi-3 3.8B (Q4_0)
Infrastructure: Standard_D4as_v4
Resource Requirements:
  CPU: 2-4 cores
  Memory: 4-8GB
```

### **Next Steps**
1. Deploy to production AKS cluster
2. Configure monitoring dashboards
3. Set 30-second SLA target

---

## Supporting Data

### **Test Methodology**
- 50 diagnostic scenarios tested
- 3 iterations per category
- GPT-4 accuracy validation
- Real Kubernetes failure cases

### **Performance Metrics**

| Metric | Value |
|--------|-------|
| Total Tests Run | 150 |
| Pass Rate | 85% |
| Average Latency | 27s |
| Token Rate | 35/s |

---

*Prepared by: Engineering Team | Date: August 28, 2025*