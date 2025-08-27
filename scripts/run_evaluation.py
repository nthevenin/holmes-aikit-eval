#!/usr/bin/env python3
"""
HolmesGPT CPU Model Evaluation Script
Runs HolmesGPT evaluations against various CPU-optimized models
"""

import os
import json
import subprocess
import sys
import time
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import yaml
import pandas as pd
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ModelEvaluator:
    """Evaluates CPU-optimized models with HolmesGPT"""
    
    def __init__(self, config_path: str):
        """Initialize evaluator with configuration"""
        self.config = self._load_config(config_path)
        self.results_dir = Path(self.config.get('results_dir', 'results'))
        self.results_dir.mkdir(exist_ok=True)
        self.timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration from YAML file"""
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def setup_model_endpoint(self, model_config: Dict) -> str:
        """Setup model endpoint based on provider (AIKit, Ollama, etc.)"""
        provider = model_config.get('provider', 'ollama')
        
        if provider == 'ollama':
            return self._setup_ollama(model_config)
        elif provider == 'aikit':
            return self._setup_aikit(model_config)
        elif provider == 'local':
            return model_config.get('endpoint', 'http://localhost:8080')
        else:
            raise ValueError(f"Unknown provider: {provider}")
    
    def _setup_ollama(self, model_config: Dict) -> str:
        """Setup Ollama model and return endpoint"""
        model_name = model_config['name']
        quantization = model_config.get('quantization', 'Q4_K_M')
        
        # Pull model if needed
        logger.info(f"Setting up Ollama model: {model_name} ({quantization})")
        subprocess.run(['ollama', 'pull', f"{model_name}:{quantization}"], check=True)
        
        # Start Ollama server if not running
        # Note: In production, this would be running in the K8s cluster
        return "http://localhost:11434"
    
    def _setup_aikit(self, model_config: Dict) -> str:
        """Setup AIKit model and return endpoint"""
        model_name = model_config['name']
        
        logger.info(f"Setting up AIKit model: {model_name}")
        # Deploy model to K8s cluster using AIKit
        # This would involve kubectl commands to deploy the model
        
        # For now, return expected endpoint
        return f"http://{model_name}-service.default.svc.cluster.local:8080"
    
    def run_holmes_eval(self, model_endpoint: str, model_name: str, 
                       eval_type: str = 'easy', iterations: int = 1) -> Dict:
        """Run HolmesGPT evaluation for a specific model"""
        
        logger.info(f"Running {eval_type} evals for {model_name} ({iterations} iterations)")
        
        env = os.environ.copy()
        env['RUN_LIVE'] = 'true'
        env['MODEL'] = model_endpoint
        env['CLASSIFIER_MODEL'] = self.config.get('classifier_model', 'gpt-4o')
        env['ITERATIONS'] = str(iterations)
        
        # Run pytest command
        cmd = [
            'poetry', 'run', 'pytest',
            '-m', f'llm and {eval_type}',
            '--no-cov',
            '--json-report',
            '--json-report-file', f"{self.results_dir}/{model_name}_{eval_type}_{self.timestamp}.json"
        ]
        
        start_time = time.time()
        result = subprocess.run(cmd, env=env, capture_output=True, text=True, cwd='holmes')
        end_time = time.time()
        
        # Parse results
        report_path = f"{self.results_dir}/{model_name}_{eval_type}_{self.timestamp}.json"
        if os.path.exists(report_path):
            with open(report_path, 'r') as f:
                test_results = json.load(f)
        else:
            test_results = {}
        
        return {
            'model': model_name,
            'eval_type': eval_type,
            'iterations': iterations,
            'total_time': end_time - start_time,
            'success': result.returncode == 0,
            'test_results': test_results,
            'stdout': result.stdout,
            'stderr': result.stderr
        }
    
    def evaluate_model(self, model_config: Dict) -> Dict:
        """Evaluate a single model configuration"""
        model_name = model_config['name']
        quantization = model_config.get('quantization', 'default')
        full_name = f"{model_name}_{quantization}"
        
        logger.info(f"Starting evaluation for {full_name}")
        
        try:
            # Setup model endpoint
            endpoint = self.setup_model_endpoint(model_config)
            
            # Measure resource usage before
            resource_before = self._measure_resources()
            
            results = {
                'model': full_name,
                'config': model_config,
                'endpoint': endpoint,
                'evaluations': {}
            }
            
            # Run evaluations for different difficulty levels
            for eval_type in self.config.get('eval_types', ['easy', 'medium']):
                iterations = self.config.get('iterations', {}).get(eval_type, 1)
                eval_result = self.run_holmes_eval(endpoint, full_name, eval_type, iterations)
                results['evaluations'][eval_type] = eval_result
            
            # Measure resource usage after
            resource_after = self._measure_resources()
            results['resource_usage'] = {
                'before': resource_before,
                'after': resource_after,
                'delta': self._calculate_resource_delta(resource_before, resource_after)
            }
            
            # Test latency
            results['latency'] = self._test_latency(endpoint)
            
            return results
            
        except Exception as e:
            logger.error(f"Error evaluating {full_name}: {str(e)}")
            return {
                'model': full_name,
                'error': str(e),
                'config': model_config
            }
    
    def _measure_resources(self) -> Dict:
        """Measure current system resource usage"""
        try:
            import psutil
            return {
                'cpu_percent': psutil.cpu_percent(interval=1),
                'memory_percent': psutil.virtual_memory().percent,
                'memory_mb': psutil.virtual_memory().used / (1024 * 1024),
                'timestamp': time.time()
            }
        except ImportError:
            return {}
    
    def _calculate_resource_delta(self, before: Dict, after: Dict) -> Dict:
        """Calculate resource usage delta"""
        if not before or not after:
            return {}
        
        return {
            'cpu_percent': after['cpu_percent'] - before['cpu_percent'],
            'memory_mb': after['memory_mb'] - before['memory_mb'],
            'duration': after['timestamp'] - before['timestamp']
        }
    
    def _test_latency(self, endpoint: str, num_tests: int = 10) -> Dict:
        """Test model response latency"""
        import requests
        
        latencies = []
        test_prompt = "What is the status of pod nginx-abc123?"
        
        for _ in range(num_tests):
            start = time.time()
            try:
                response = requests.post(
                    f"{endpoint}/v1/completions",
                    json={"prompt": test_prompt, "max_tokens": 100},
                    timeout=30
                )
                latency = time.time() - start
                if response.status_code == 200:
                    latencies.append(latency)
            except Exception as e:
                logger.warning(f"Latency test failed: {e}")
        
        if latencies:
            return {
                'min': min(latencies),
                'max': max(latencies),
                'avg': sum(latencies) / len(latencies),
                'p50': sorted(latencies)[len(latencies)//2],
                'p90': sorted(latencies)[int(len(latencies)*0.9)],
                'samples': len(latencies)
            }
        return {}
    
    def run_evaluation(self) -> None:
        """Run evaluation for all configured models"""
        models = self.config.get('models', [])
        
        if not models:
            logger.error("No models configured for evaluation")
            return
        
        all_results = []
        
        # Run evaluations in parallel if configured
        max_workers = self.config.get('parallel_workers', 1)
        
        if max_workers > 1:
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                futures = {executor.submit(self.evaluate_model, model): model 
                          for model in models}
                
                for future in as_completed(futures):
                    result = future.result()
                    all_results.append(result)
                    self._save_intermediate_results(result)
        else:
            for model in models:
                result = self.evaluate_model(model)
                all_results.append(result)
                self._save_intermediate_results(result)
        
        # Save final results
        self._save_final_results(all_results)
        
        # Generate comparison report
        self._generate_comparison_report(all_results)
    
    def _save_intermediate_results(self, result: Dict) -> None:
        """Save intermediate results for a single model"""
        model_name = result['model']
        output_file = self.results_dir / f"{model_name}_{self.timestamp}.json"
        
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2, default=str)
        
        logger.info(f"Saved intermediate results to {output_file}")
    
    def _save_final_results(self, results: List[Dict]) -> None:
        """Save all evaluation results"""
        output_file = self.results_dir / f"evaluation_results_{self.timestamp}.json"
        
        with open(output_file, 'w') as f:
            json.dump({
                'timestamp': self.timestamp,
                'config': self.config,
                'results': results
            }, f, indent=2, default=str)
        
        logger.info(f"Saved final results to {output_file}")
    
    def _generate_comparison_report(self, results: List[Dict]) -> None:
        """Generate comparison report for all models"""
        report_file = self.results_dir / f"comparison_report_{self.timestamp}.md"
        
        with open(report_file, 'w') as f:
            f.write("# HolmesGPT CPU Model Evaluation Report\n\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            # Summary table
            f.write("## Summary\n\n")
            f.write("| Model | Easy Pass Rate | Medium Pass Rate | Avg Latency (s) | Memory (MB) |\n")
            f.write("|-------|---------------|------------------|-----------------|-------------|\n")
            
            for result in results:
                if 'error' in result:
                    f.write(f"| {result['model']} | ERROR | ERROR | ERROR | ERROR |\n")
                    continue
                
                easy_rate = self._calculate_pass_rate(result, 'easy')
                medium_rate = self._calculate_pass_rate(result, 'medium')
                avg_latency = result.get('latency', {}).get('avg', 'N/A')
                memory = result.get('resource_usage', {}).get('delta', {}).get('memory_mb', 'N/A')
                
                f.write(f"| {result['model']} | {easy_rate:.1%} | {medium_rate:.1%} | "
                       f"{avg_latency:.2f} | {memory:.0f} |\n")
            
            # Detailed results
            f.write("\n## Detailed Results\n\n")
            for result in results:
                f.write(f"### {result['model']}\n\n")
                
                if 'error' in result:
                    f.write(f"**Error:** {result['error']}\n\n")
                    continue
                
                # Configuration
                f.write("**Configuration:**\n")
                f.write(f"- Provider: {result['config'].get('provider')}\n")
                f.write(f"- Quantization: {result['config'].get('quantization')}\n")
                f.write(f"- Endpoint: {result['endpoint']}\n\n")
                
                # Test results
                for eval_type, eval_result in result.get('evaluations', {}).items():
                    f.write(f"**{eval_type.capitalize()} Tests:**\n")
                    f.write(f"- Pass Rate: {self._calculate_pass_rate(result, eval_type):.1%}\n")
                    f.write(f"- Total Time: {eval_result.get('total_time', 0):.1f}s\n")
                    f.write(f"- Iterations: {eval_result.get('iterations', 1)}\n\n")
                
                # Resource usage
                if 'resource_usage' in result:
                    delta = result['resource_usage'].get('delta', {})
                    f.write("**Resource Usage:**\n")
                    f.write(f"- CPU Delta: {delta.get('cpu_percent', 0):.1f}%\n")
                    f.write(f"- Memory Delta: {delta.get('memory_mb', 0):.0f} MB\n\n")
                
                # Latency
                if 'latency' in result:
                    lat = result['latency']
                    f.write("**Latency:**\n")
                    f.write(f"- Average: {lat.get('avg', 0):.3f}s\n")
                    f.write(f"- P50: {lat.get('p50', 0):.3f}s\n")
                    f.write(f"- P90: {lat.get('p90', 0):.3f}s\n\n")
        
        logger.info(f"Generated comparison report: {report_file}")
    
    def _calculate_pass_rate(self, result: Dict, eval_type: str) -> float:
        """Calculate pass rate for a specific evaluation type"""
        eval_result = result.get('evaluations', {}).get(eval_type, {})
        test_results = eval_result.get('test_results', {})
        
        if not test_results or 'tests' not in test_results:
            return 0.0
        
        tests = test_results['tests']
        if not tests:
            return 0.0
        
        passed = sum(1 for test in tests if test.get('outcome') == 'passed')
        return passed / len(tests)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Run HolmesGPT CPU model evaluation')
    parser.add_argument('--config', '-c', default='config/evaluation.yaml',
                       help='Path to evaluation configuration file')
    parser.add_argument('--model', '-m', help='Evaluate specific model only')
    parser.add_argument('--parallel', '-p', type=int, default=1,
                       help='Number of parallel evaluations')
    
    args = parser.parse_args()
    
    # Check if config file exists
    if not os.path.exists(args.config):
        logger.error(f"Configuration file not found: {args.config}")
        sys.exit(1)
    
    # Run evaluation
    evaluator = ModelEvaluator(args.config)
    
    if args.parallel > 1:
        evaluator.config['parallel_workers'] = args.parallel
    
    if args.model:
        # Filter to specific model
        models = evaluator.config.get('models', [])
        evaluator.config['models'] = [m for m in models if m['name'] == args.model]
    
    evaluator.run_evaluation()


if __name__ == '__main__':
    main()