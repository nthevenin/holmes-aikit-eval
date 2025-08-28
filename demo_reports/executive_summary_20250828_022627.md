# Executive Summary: HolmesGPT CPU Model Evaluation

**Date:** 2025-08-28

## Key Findings

1. **Best Overall Model:** phi3.5_Q4_K_M with 83.3% pass rate
2. **Viable CPU Models:** 1 models achieve >70% pass rate
3. **Latency Range:** 2.1s - 3.1s
4. **Memory Requirements:** 1536MB - 3072MB

## Recommendations for Production

### Primary Recommendation: phi3.5_Q4_K_M

- Pass Rate: 83.3%
- Latency: 3.10s
- Memory: 3072MB

## Cost Comparison

| Deployment Option | Monthly Cost (Est.) | Pass Rate |
|-------------------|-------------------|----------|
| CPU Model (phi3.5_Q4_K_M) | $50-100 | 83.3% |
| GPU (V100) | $2000-3000 | ~95% |
| OpenAI API | $500-2000 | ~98% |

## Recommended Next Steps

1. Deploy recommended model in staging environment
2. Conduct A/B testing with subset of users
3. Monitor performance metrics in production
4. Consider model fine-tuning for K8s-specific scenarios
5. Implement fallback to API-based models for complex cases
