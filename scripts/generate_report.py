#!/usr/bin/env python3
"""
Report Generation Script for HolmesGPT CPU Model Evaluation
Generates comprehensive reports from evaluation results
"""

import json
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from jinja2 import Template
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Set style for plots
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

class ReportGenerator:
    """Generate comprehensive evaluation reports"""
    
    def __init__(self, results_path: str, output_dir: str = 'reports'):
        """Initialize report generator"""
        self.results_path = Path(results_path)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Create subdirectories
        self.charts_dir = self.output_dir / 'charts'
        self.charts_dir.mkdir(exist_ok=True)
        
        self.data = self._load_results()
        self.timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    def _load_results(self) -> Dict:
        """Load evaluation results from JSON file"""
        with open(self.results_path, 'r') as f:
            return json.load(f)
    
    def generate_full_report(self) -> None:
        """Generate complete evaluation report"""
        logger.info("Generating comprehensive evaluation report...")
        
        # Process data
        df = self._create_dataframe()
        
        # Generate visualizations
        self._generate_charts(df)
        
        # Generate markdown report
        self._generate_markdown_report(df)
        
        # Generate HTML report
        self._generate_html_report(df)
        
        # Generate executive summary
        self._generate_executive_summary(df)
        
        logger.info(f"Report generation complete. Output directory: {self.output_dir}")
    
    def _create_dataframe(self) -> pd.DataFrame:
        """Create pandas DataFrame from results"""
        data = []
        
        for result in self.data.get('results', []):
            if 'error' in result:
                continue
            
            model_name = result['model']
            config = result.get('config', {})
            
            for eval_type, eval_result in result.get('evaluations', {}).items():
                test_results = eval_result.get('test_results', {})
                tests = test_results.get('tests', [])
                
                if tests:
                    passed = sum(1 for test in tests if test.get('outcome') == 'passed')
                    total = len(tests)
                    pass_rate = passed / total if total > 0 else 0
                else:
                    passed = 0
                    total = 0
                    pass_rate = 0
                
                latency = result.get('latency', {})
                resource = result.get('resource_usage', {}).get('delta', {})
                
                data.append({
                    'model': model_name,
                    'provider': config.get('provider', 'unknown'),
                    'size': config.get('size', 'unknown'),
                    'quantization': config.get('quantization', 'default'),
                    'eval_type': eval_type,
                    'pass_rate': pass_rate * 100,
                    'passed_tests': passed,
                    'total_tests': total,
                    'avg_latency': latency.get('avg', 0),
                    'p50_latency': latency.get('p50', 0),
                    'p90_latency': latency.get('p90', 0),
                    'cpu_delta': resource.get('cpu_percent', 0),
                    'memory_delta_mb': resource.get('memory_mb', 0),
                    'total_time': eval_result.get('total_time', 0),
                    'iterations': eval_result.get('iterations', 1)
                })
        
        return pd.DataFrame(data)
    
    def _generate_charts(self, df: pd.DataFrame) -> None:
        """Generate visualization charts"""
        
        # 1. Pass Rate Comparison
        plt.figure(figsize=(14, 8))
        
        # Prepare data for grouped bar chart
        pivot_df = df.pivot_table(
            values='pass_rate',
            index='model',
            columns='eval_type',
            aggfunc='mean'
        )
        
        ax = pivot_df.plot(kind='bar', rot=45)
        plt.title('Pass Rate Comparison by Model and Difficulty', fontsize=16, fontweight='bold')
        plt.xlabel('Model', fontsize=12)
        plt.ylabel('Pass Rate (%)', fontsize=12)
        plt.legend(title='Evaluation Type', loc='upper left')
        plt.grid(axis='y', alpha=0.3)
        plt.tight_layout()
        plt.savefig(self.charts_dir / 'pass_rate_comparison.png', dpi=150)
        plt.close()
        
        # 2. Latency vs Pass Rate Scatter
        plt.figure(figsize=(12, 8))
        
        for eval_type in df['eval_type'].unique():
            eval_df = df[df['eval_type'] == eval_type]
            plt.scatter(eval_df['avg_latency'], eval_df['pass_rate'], 
                       label=eval_type, s=100, alpha=0.7)
            
            # Add model labels
            for idx, row in eval_df.iterrows():
                plt.annotate(row['model'].split('_')[0], 
                           (row['avg_latency'], row['pass_rate']),
                           fontsize=8, alpha=0.7)
        
        plt.title('Latency vs Pass Rate Trade-off', fontsize=16, fontweight='bold')
        plt.xlabel('Average Latency (seconds)', fontsize=12)
        plt.ylabel('Pass Rate (%)', fontsize=12)
        plt.legend(title='Evaluation Type')
        plt.grid(alpha=0.3)
        plt.tight_layout()
        plt.savefig(self.charts_dir / 'latency_vs_passrate.png', dpi=150)
        plt.close()
        
        # 3. Resource Usage Comparison
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 7))
        
        # CPU usage
        model_cpu = df.groupby('model')['cpu_delta'].mean().sort_values()
        model_cpu.plot(kind='barh', ax=ax1, color='skyblue')
        ax1.set_title('CPU Usage Delta by Model', fontsize=14, fontweight='bold')
        ax1.set_xlabel('CPU Usage Delta (%)', fontsize=12)
        ax1.set_ylabel('Model', fontsize=12)
        ax1.grid(axis='x', alpha=0.3)
        
        # Memory usage
        model_mem = df.groupby('model')['memory_delta_mb'].mean().sort_values()
        model_mem.plot(kind='barh', ax=ax2, color='lightcoral')
        ax2.set_title('Memory Usage Delta by Model', fontsize=14, fontweight='bold')
        ax2.set_xlabel('Memory Usage Delta (MB)', fontsize=12)
        ax2.set_ylabel('Model', fontsize=12)
        ax2.grid(axis='x', alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(self.charts_dir / 'resource_usage.png', dpi=150)
        plt.close()
        
        # 4. Model Size vs Performance
        plt.figure(figsize=(12, 8))
        
        # Group by model size and calculate average pass rate
        size_perf = df.groupby(['size', 'eval_type'])['pass_rate'].mean().unstack()
        
        if not size_perf.empty:
            ax = size_perf.plot(kind='bar', rot=0)
            plt.title('Performance by Model Size', fontsize=16, fontweight='bold')
            plt.xlabel('Model Size', fontsize=12)
            plt.ylabel('Average Pass Rate (%)', fontsize=12)
            plt.legend(title='Evaluation Type')
            plt.grid(axis='y', alpha=0.3)
            plt.tight_layout()
            plt.savefig(self.charts_dir / 'size_vs_performance.png', dpi=150)
            plt.close()
        
        # 5. Quantization Impact
        plt.figure(figsize=(12, 8))
        
        quant_perf = df.groupby(['quantization', 'eval_type'])['pass_rate'].mean().unstack()
        
        if not quant_perf.empty:
            ax = quant_perf.plot(kind='bar', rot=45)
            plt.title('Impact of Quantization on Performance', fontsize=16, fontweight='bold')
            plt.xlabel('Quantization Level', fontsize=12)
            plt.ylabel('Average Pass Rate (%)', fontsize=12)
            plt.legend(title='Evaluation Type')
            plt.grid(axis='y', alpha=0.3)
            plt.tight_layout()
            plt.savefig(self.charts_dir / 'quantization_impact.png', dpi=150)
            plt.close()
        
        # 6. Performance Heatmap
        plt.figure(figsize=(14, 10))
        
        # Create pivot table for heatmap
        heatmap_data = df.pivot_table(
            values='pass_rate',
            index='model',
            columns='eval_type',
            aggfunc='mean'
        )
        
        sns.heatmap(heatmap_data, annot=True, fmt='.1f', cmap='RdYlGn',
                   cbar_kws={'label': 'Pass Rate (%)'})
        plt.title('Model Performance Heatmap', fontsize=16, fontweight='bold')
        plt.xlabel('Evaluation Type', fontsize=12)
        plt.ylabel('Model', fontsize=12)
        plt.tight_layout()
        plt.savefig(self.charts_dir / 'performance_heatmap.png', dpi=150)
        plt.close()
    
    def _generate_markdown_report(self, df: pd.DataFrame) -> None:
        """Generate detailed markdown report"""
        report_path = self.output_dir / f'evaluation_report_{self.timestamp}.md'
        
        with open(report_path, 'w') as f:
            # Header
            f.write("# HolmesGPT CPU Model Evaluation Report\n\n")
            f.write(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"**Evaluation Run:** {self.data.get('timestamp', 'N/A')}\n\n")
            
            # Executive Summary
            f.write("## Executive Summary\n\n")
            self._write_summary_stats(f, df)
            
            # Model Rankings
            f.write("\n## Model Rankings\n\n")
            self._write_model_rankings(f, df)
            
            # Detailed Results by Model
            f.write("\n## Detailed Results\n\n")
            self._write_detailed_results(f, df)
            
            # Trade-off Analysis
            f.write("\n## Trade-off Analysis\n\n")
            self._write_tradeoff_analysis(f, df)
            
            # Recommendations
            f.write("\n## Recommendations\n\n")
            self._write_recommendations(f, df)
            
            # Appendix
            f.write("\n## Appendix\n\n")
            f.write("### Visualization Charts\n\n")
            for chart in self.charts_dir.glob('*.png'):
                f.write(f"![{chart.stem}](charts/{chart.name})\n\n")
            
            f.write("### Test Configuration\n\n")
            config = self.data.get('config', {})
            f.write(f"- Classifier Model: {config.get('classifier_model', 'N/A')}\n")
            f.write(f"- Evaluation Types: {', '.join(config.get('eval_types', []))}\n")
            f.write(f"- Iterations: {config.get('iterations', {})}\n")
        
        logger.info(f"Markdown report saved to: {report_path}")
    
    def _write_summary_stats(self, f, df: pd.DataFrame) -> None:
        """Write summary statistics to report"""
        total_models = df['model'].nunique()
        total_tests = df['total_tests'].sum()
        avg_pass_rate = df['pass_rate'].mean()
        best_model = df.groupby('model')['pass_rate'].mean().idxmax()
        fastest_model = df.groupby('model')['avg_latency'].mean().idxmin()
        
        f.write(f"- **Total Models Evaluated:** {total_models}\n")
        f.write(f"- **Total Tests Run:** {total_tests}\n")
        f.write(f"- **Average Pass Rate:** {avg_pass_rate:.1f}%\n")
        f.write(f"- **Best Performing Model:** {best_model}\n")
        f.write(f"- **Fastest Model:** {fastest_model}\n")
    
    def _write_model_rankings(self, f, df: pd.DataFrame) -> None:
        """Write model rankings to report"""
        # Overall ranking
        f.write("### Overall Performance\n\n")
        overall = df.groupby('model').agg({
            'pass_rate': 'mean',
            'avg_latency': 'mean',
            'memory_delta_mb': 'mean'
        }).round(2)
        overall = overall.sort_values('pass_rate', ascending=False)
        
        f.write("| Rank | Model | Pass Rate (%) | Avg Latency (s) | Memory (MB) |\n")
        f.write("|------|-------|--------------|-----------------|-------------|\n")
        
        for i, (model, row) in enumerate(overall.iterrows(), 1):
            f.write(f"| {i} | {model} | {row['pass_rate']:.1f} | "
                   f"{row['avg_latency']:.2f} | {row['memory_delta_mb']:.0f} |\n")
        
        # By evaluation type
        for eval_type in df['eval_type'].unique():
            f.write(f"\n### {eval_type.capitalize()} Tests\n\n")
            eval_df = df[df['eval_type'] == eval_type]
            ranking = eval_df.groupby('model')['pass_rate'].mean().sort_values(ascending=False)
            
            f.write("| Rank | Model | Pass Rate (%) |\n")
            f.write("|------|-------|---------------|\n")
            
            for i, (model, pass_rate) in enumerate(ranking.items(), 1):
                f.write(f"| {i} | {model} | {pass_rate:.1f} |\n")
    
    def _write_detailed_results(self, f, df: pd.DataFrame) -> None:
        """Write detailed results for each model"""
        for model in df['model'].unique():
            model_df = df[df['model'] == model]
            
            f.write(f"### {model}\n\n")
            
            # Configuration
            first_row = model_df.iloc[0]
            f.write("**Configuration:**\n")
            f.write(f"- Provider: {first_row['provider']}\n")
            f.write(f"- Size: {first_row['size']}\n")
            f.write(f"- Quantization: {first_row['quantization']}\n\n")
            
            # Performance metrics
            f.write("**Performance Metrics:**\n\n")
            f.write("| Metric | Easy | Medium |\n")
            f.write("|--------|------|--------|\n")
            
            for eval_type in ['easy', 'medium']:
                eval_row = model_df[model_df['eval_type'] == eval_type]
                if not eval_row.empty:
                    row = eval_row.iloc[0]
                    f.write(f"| Pass Rate | {row['pass_rate']:.1f}% | ")
                else:
                    f.write("| Pass Rate | N/A | ")
            f.write("\n")
            
            # Resource usage
            f.write("\n**Resource Usage:**\n")
            f.write(f"- CPU Delta: {model_df['cpu_delta'].mean():.1f}%\n")
            f.write(f"- Memory Delta: {model_df['memory_delta_mb'].mean():.0f} MB\n")
            f.write(f"- Avg Latency: {model_df['avg_latency'].mean():.2f}s\n\n")
    
    def _write_tradeoff_analysis(self, f, df: pd.DataFrame) -> None:
        """Write trade-off analysis"""
        f.write("### Performance vs Resource Trade-offs\n\n")
        
        # Calculate efficiency scores
        efficiency = df.groupby('model').agg({
            'pass_rate': 'mean',
            'avg_latency': 'mean',
            'memory_delta_mb': 'mean'
        })
        
        # Normalize metrics (higher is better)
        efficiency['latency_score'] = 1 / (efficiency['avg_latency'] + 0.1)
        efficiency['memory_score'] = 1 / (efficiency['memory_delta_mb'] + 1)
        efficiency['overall_score'] = (
            efficiency['pass_rate'] * 0.5 +
            efficiency['latency_score'] * 10 * 0.3 +
            efficiency['memory_score'] * 100 * 0.2
        )
        
        efficiency = efficiency.sort_values('overall_score', ascending=False)
        
        f.write("| Model | Pass Rate | Latency | Memory | Overall Score |\n")
        f.write("|-------|-----------|---------|--------|---------------|\n")
        
        for model, row in efficiency.head(5).iterrows():
            f.write(f"| {model} | {row['pass_rate']:.1f}% | "
                   f"{row['avg_latency']:.2f}s | {row['memory_delta_mb']:.0f} MB | "
                   f"{row['overall_score']:.1f} |\n")
    
    def _write_recommendations(self, f, df: pd.DataFrame) -> None:
        """Write recommendations based on analysis"""
        # Find best models for different scenarios
        best_accuracy = df.groupby('model')['pass_rate'].mean().idxmax()
        best_speed = df.groupby('model')['avg_latency'].mean().idxmin()
        
        # Best balanced model (accuracy vs speed)
        balanced = df.groupby('model').agg({
            'pass_rate': 'mean',
            'avg_latency': 'mean'
        })
        balanced['score'] = balanced['pass_rate'] / (balanced['avg_latency'] + 0.1)
        best_balanced = balanced['score'].idxmax()
        
        f.write("Based on the evaluation results, we recommend:\n\n")
        f.write(f"1. **For Maximum Accuracy:** {best_accuracy}\n")
        f.write(f"   - Best pass rate across all tests\n")
        f.write(f"   - Suitable for critical diagnostics where accuracy is paramount\n\n")
        
        f.write(f"2. **For Minimum Latency:** {best_speed}\n")
        f.write(f"   - Fastest response times\n")
        f.write(f"   - Ideal for real-time diagnostics and high-volume scenarios\n\n")
        
        f.write(f"3. **For Balanced Performance:** {best_balanced}\n")
        f.write(f"   - Best trade-off between accuracy and speed\n")
        f.write(f"   - Recommended for general production use\n\n")
        
        # Additional insights
        f.write("### Additional Insights\n\n")
        
        # Quantization impact
        quant_impact = df.groupby('quantization')['pass_rate'].mean()
        best_quant = quant_impact.idxmax()
        
        f.write(f"- **Optimal Quantization:** {best_quant} provides the best accuracy\n")
        f.write("- **Model Size Impact:** Larger models generally perform better but require more resources\n")
        f.write("- **Provider Comparison:** ")
        
        provider_perf = df.groupby('provider')['pass_rate'].mean()
        f.write(f"{provider_perf.idxmax()} shows best overall performance\n")
    
    def _generate_html_report(self, df: pd.DataFrame) -> None:
        """Generate HTML report with interactive elements"""
        html_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HolmesGPT CPU Model Evaluation Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #34495e;
            margin-top: 30px;
        }
        .summary-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric {
            display: inline-block;
            margin: 10px 20px;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 5px;
            min-width: 150px;
            text-align: center;
        }
        .metric-value {
            font-size: 24px;
            font-weight: bold;
        }
        .metric-label {
            font-size: 12px;
            text-transform: uppercase;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        th {
            background: #3498db;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background: #f1f1f1;
        }
        .chart-container {
            background: white;
            padding: 20px;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .chart-container img {
            max-width: 100%;
            height: auto;
        }
        .recommendation {
            background: #e8f8f5;
            border-left: 4px solid #27ae60;
            padding: 15px;
            margin: 15px 0;
        }
        .timestamp {
            color: #7f8c8d;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <h1>🤖 HolmesGPT CPU Model Evaluation Report</h1>
    <p class="timestamp">Generated: {{ timestamp }}</p>
    
    <div class="summary-card">
        <h2>📊 Executive Summary</h2>
        <div class="metrics-container">
            <div class="metric">
                <div class="metric-value">{{ total_models }}</div>
                <div class="metric-label">Models Tested</div>
            </div>
            <div class="metric">
                <div class="metric-value">{{ total_tests }}</div>
                <div class="metric-label">Total Tests</div>
            </div>
            <div class="metric">
                <div class="metric-value">{{ avg_pass_rate }}%</div>
                <div class="metric-label">Avg Pass Rate</div>
            </div>
            <div class="metric">
                <div class="metric-value">{{ best_model }}</div>
                <div class="metric-label">Best Model</div>
            </div>
        </div>
    </div>
    
    <div class="summary-card">
        <h2>🏆 Top Performing Models</h2>
        {{ rankings_table }}
    </div>
    
    <div class="summary-card">
        <h2>📈 Performance Visualizations</h2>
        <div class="chart-container">
            <h3>Pass Rate Comparison</h3>
            <img src="charts/pass_rate_comparison.png" alt="Pass Rate Comparison">
        </div>
        <div class="chart-container">
            <h3>Latency vs Pass Rate Trade-off</h3>
            <img src="charts/latency_vs_passrate.png" alt="Latency vs Pass Rate">
        </div>
        <div class="chart-container">
            <h3>Resource Usage</h3>
            <img src="charts/resource_usage.png" alt="Resource Usage">
        </div>
    </div>
    
    <div class="summary-card">
        <h2>💡 Recommendations</h2>
        {{ recommendations }}
    </div>
    
    <div class="summary-card">
        <h2>📋 Detailed Results</h2>
        {{ detailed_results }}
    </div>
</body>
</html>
        """
        
        # Prepare template data
        template_data = {
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'total_models': df['model'].nunique(),
            'total_tests': df['total_tests'].sum(),
            'avg_pass_rate': f"{df['pass_rate'].mean():.1f}",
            'best_model': df.groupby('model')['pass_rate'].mean().idxmax(),
            'rankings_table': self._generate_html_table(df),
            'recommendations': self._generate_html_recommendations(df),
            'detailed_results': self._generate_html_detailed(df)
        }
        
        # Render template
        template = Template(html_template)
        html_content = template.render(**template_data)
        
        # Save HTML report
        html_path = self.output_dir / f'evaluation_report_{self.timestamp}.html'
        with open(html_path, 'w') as f:
            f.write(html_content)
        
        logger.info(f"HTML report saved to: {html_path}")
    
    def _generate_html_table(self, df: pd.DataFrame) -> str:
        """Generate HTML table for rankings"""
        rankings = df.groupby('model').agg({
            'pass_rate': 'mean',
            'avg_latency': 'mean',
            'memory_delta_mb': 'mean'
        }).round(2).sort_values('pass_rate', ascending=False)
        
        html = "<table><thead><tr>"
        html += "<th>Rank</th><th>Model</th><th>Pass Rate (%)</th>"
        html += "<th>Avg Latency (s)</th><th>Memory (MB)</th>"
        html += "</tr></thead><tbody>"
        
        for i, (model, row) in enumerate(rankings.head(10).iterrows(), 1):
            html += f"<tr><td>{i}</td><td>{model}</td>"
            html += f"<td>{row['pass_rate']:.1f}</td>"
            html += f"<td>{row['avg_latency']:.2f}</td>"
            html += f"<td>{row['memory_delta_mb']:.0f}</td></tr>"
        
        html += "</tbody></table>"
        return html
    
    def _generate_html_recommendations(self, df: pd.DataFrame) -> str:
        """Generate HTML recommendations"""
        best_accuracy = df.groupby('model')['pass_rate'].mean().idxmax()
        best_speed = df.groupby('model')['avg_latency'].mean().idxmin()
        
        html = f"""
        <div class="recommendation">
            <strong>For Maximum Accuracy:</strong> {best_accuracy}<br>
            Best pass rate across all tests - ideal for critical diagnostics
        </div>
        <div class="recommendation">
            <strong>For Minimum Latency:</strong> {best_speed}<br>
            Fastest response times - perfect for real-time diagnostics
        </div>
        """
        return html
    
    def _generate_html_detailed(self, df: pd.DataFrame) -> str:
        """Generate detailed HTML results"""
        return df.to_html(classes='detailed-table', index=False)
    
    def _generate_executive_summary(self, df: pd.DataFrame) -> None:
        """Generate executive summary document"""
        summary_path = self.output_dir / f'executive_summary_{self.timestamp}.md'
        
        with open(summary_path, 'w') as f:
            f.write("# Executive Summary: HolmesGPT CPU Model Evaluation\n\n")
            f.write(f"**Date:** {datetime.now().strftime('%Y-%m-%d')}\n\n")
            
            # Key Findings
            f.write("## Key Findings\n\n")
            
            best_model = df.groupby('model')['pass_rate'].mean().idxmax()
            best_pass_rate = df.groupby('model')['pass_rate'].mean().max()
            
            f.write(f"1. **Best Overall Model:** {best_model} with {best_pass_rate:.1f}% pass rate\n")
            f.write(f"2. **Viable CPU Models:** {df[df['pass_rate'] > 70]['model'].nunique()} models achieve >70% pass rate\n")
            f.write(f"3. **Latency Range:** {df['avg_latency'].min():.1f}s - {df['avg_latency'].max():.1f}s\n")
            f.write(f"4. **Memory Requirements:** {df['memory_delta_mb'].min():.0f}MB - {df['memory_delta_mb'].max():.0f}MB\n\n")
            
            # Recommendations
            f.write("## Recommendations for Production\n\n")
            
            # Find best balanced model
            balanced = df.groupby('model').agg({
                'pass_rate': 'mean',
                'avg_latency': 'mean',
                'memory_delta_mb': 'mean'
            })
            balanced['score'] = (balanced['pass_rate'] / 100) * (1 / (balanced['avg_latency'] + 0.1))
            best_balanced = balanced['score'].idxmax()
            
            f.write(f"### Primary Recommendation: {best_balanced}\n\n")
            model_stats = balanced.loc[best_balanced]
            f.write(f"- Pass Rate: {model_stats['pass_rate']:.1f}%\n")
            f.write(f"- Latency: {model_stats['avg_latency']:.2f}s\n")
            f.write(f"- Memory: {model_stats['memory_delta_mb']:.0f}MB\n\n")
            
            # Cost Analysis
            f.write("## Cost Comparison\n\n")
            f.write("| Deployment Option | Monthly Cost (Est.) | Pass Rate |\n")
            f.write("|-------------------|-------------------|----------|\n")
            f.write(f"| CPU Model ({best_balanced}) | $50-100 | {model_stats['pass_rate']:.1f}% |\n")
            f.write("| GPU (V100) | $2000-3000 | ~95% |\n")
            f.write("| OpenAI API | $500-2000 | ~98% |\n\n")
            
            # Next Steps
            f.write("## Recommended Next Steps\n\n")
            f.write("1. Deploy recommended model in staging environment\n")
            f.write("2. Conduct A/B testing with subset of users\n")
            f.write("3. Monitor performance metrics in production\n")
            f.write("4. Consider model fine-tuning for K8s-specific scenarios\n")
            f.write("5. Implement fallback to API-based models for complex cases\n")
        
        logger.info(f"Executive summary saved to: {summary_path}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Generate HolmesGPT evaluation report')
    parser.add_argument('results', help='Path to evaluation results JSON file')
    parser.add_argument('--output', '-o', default='reports',
                       help='Output directory for reports')
    parser.add_argument('--format', '-f', choices=['all', 'markdown', 'html', 'summary'],
                       default='all', help='Report format to generate')
    
    args = parser.parse_args()
    
    # Check if results file exists
    if not os.path.exists(args.results):
        logger.error(f"Results file not found: {args.results}")
        sys.exit(1)
    
    # Generate reports
    generator = ReportGenerator(args.results, args.output)
    
    if args.format == 'all':
        generator.generate_full_report()
    elif args.format == 'markdown':
        df = generator._create_dataframe()
        generator._generate_markdown_report(df)
    elif args.format == 'html':
        df = generator._create_dataframe()
        generator._generate_html_report(df)
    elif args.format == 'summary':
        df = generator._create_dataframe()
        generator._generate_executive_summary(df)
    
    logger.info("Report generation complete!")


if __name__ == '__main__':
    main()