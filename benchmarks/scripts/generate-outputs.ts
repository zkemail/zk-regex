#!/usr/bin/env bun
/**
 * Generate output formats from benchmark results.
 *
 * Produces:
 * - outputs/results.md (Markdown tables)
 * - outputs/tables.tex (LaTeX tables for academic paper)
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import type { BenchmarkResults, PatternBenchmark, TimingStats } from '../src/types.js';

const RESULTS_FILE = path.join(import.meta.dir, '..', 'results', 'comparison.json');
const OUTPUT_DIR = path.join(import.meta.dir, '..', 'outputs');

/**
 * Format timing stats with uncertainty for LaTeX (siunitx format).
 */
function formatTimingLatex(stats: TimingStats): string {
  return `${stats.mean.toFixed(0)} +- ${stats.stddev.toFixed(0)}`;
}

/**
 * Format timing stats for Markdown.
 */
function formatTimingMarkdown(stats: TimingStats): string {
  return `${stats.mean.toFixed(1)} ± ${stats.stddev.toFixed(1)}`;
}

/**
 * Generate Markdown tables.
 */
function generateMarkdown(results: BenchmarkResults): string {
  const lines: string[] = [
    '# ZK-Regex Benchmark Results',
    '',
    `Generated: ${results.hardware.timestamp}`,
    '',
    '## Hardware',
    '',
    `- **Platform**: ${results.hardware.platform}`,
    `- **CPU**: ${results.hardware.cpu}`,
    `- **Cores**: ${results.hardware.cores}`,
    `- **Memory**: ${results.hardware.memoryGB}GB`,
    `- **OS**: ${results.hardware.os}`,
    '',
    '## Tool Versions',
    '',
    `- **Bun**: ${results.toolVersions.bun}`,
    `- **Circom**: ${results.toolVersions.circom ?? 'N/A'}`,
    `- **Nargo**: ${results.toolVersions.nargo ?? 'N/A'}`,
    '',
    '## Constraint Count Comparison',
    '',
    '| Pattern | v1 (DFA) | v2 (NFA) | Reduction | v2 States | v2 Transitions |',
    '|---------|----------|----------|-----------|-----------|----------------|',
  ];

  // Add pattern rows (placeholder)
  for (const [name, data] of Object.entries(results.patterns)) {
    const v1 = data.v1Circom?.constraints ?? '—';
    const v2 = data.v2Circom.constraints;
    const reduction = data.v1Circom
      ? `${((1 - v2 / data.v1Circom.constraints) * 100).toFixed(1)}%`
      : '—';
    const states = data.v2Circom.states;
    const transitions = data.v2Circom.transitions;
    lines.push(`| ${name} | ${v1} | ${v2} | ${reduction} | ${states} | ${transitions} |`);
  }

  lines.push('');
  lines.push('## Proving Time Comparison (Circom/Groth16)');
  lines.push('');
  lines.push('| Pattern | v1 Prove (ms) | v2 Prove (ms) | Speedup |');
  lines.push('|---------|---------------|---------------|---------|');

  for (const [name, data] of Object.entries(results.patterns)) {
    const v1Prove = data.v1Circom ? formatTimingMarkdown(data.v1Circom.proveMs) : '—';
    const v2Prove = formatTimingMarkdown(data.v2Circom.proveMs);
    const speedup = data.v1Circom
      ? `${(data.v1Circom.proveMs.mean / data.v2Circom.proveMs.mean).toFixed(2)}x`
      : '—';
    lines.push(`| ${name} | ${v1Prove} | ${v2Prove} | ${speedup} |`);
  }

  lines.push('');
  lines.push('## Noir Backend Performance (v2 only)');
  lines.push('');
  lines.push('| Pattern | ACIR Opcodes | Backend Gates | Prove (ms) | Verify (ms) | Proof Size |');
  lines.push('|---------|--------------|---------------|------------|-------------|------------|');

  for (const [name, data] of Object.entries(results.patterns)) {
    const noir = data.v2Noir;
    lines.push(
      `| ${name} | ${noir.acirOpcodes} | ${noir.backendGates} | ${formatTimingMarkdown(noir.proveMs)} | ${formatTimingMarkdown(noir.verifyMs)} | ${noir.proofSizeBytes}B |`
    );
  }

  return lines.join('\n');
}

/**
 * Generate LaTeX tables (booktabs + siunitx).
 */
function generateLatex(results: BenchmarkResults): string {
  const lines: string[] = [
    '% ZK-Regex Benchmark Tables',
    '% Requires: booktabs, siunitx, multirow packages',
    '',
    '% Table 1: R1CS Constraint Count Comparison',
    '\\begin{table}[htbp]',
    '\\centering',
    '\\caption{R1CS Constraint Count Comparison: DFA-based (v1) vs NFA-based (v2)}',
    '\\label{tab:constraints}',
    '\\sisetup{',
    '  table-format = 6.0,',
    '  round-mode = places,',
    '  round-precision = 0,',
    '}',
    '\\begin{tabular}{@{}l S S S[table-format=2.1] S[table-format=2.0] S[table-format=3.0]@{}}',
    '\\toprule',
    '\\multirow{2}{*}{Pattern} & \\multicolumn{2}{c}{Constraints} & {Reduction} & \\multicolumn{2}{c}{v2 Complexity} \\\\',
    '\\cmidrule(lr){2-3} \\cmidrule(l){5-6}',
    '& {v1 (DFA)} & {v2 (NFA)} & {(\\%)} & {States} & {Transitions} \\\\',
    '\\midrule',
  ];

  // Add pattern rows
  for (const [name, data] of Object.entries(results.patterns)) {
    const v1 = data.v1Circom?.constraints ?? '{---}';
    const v2 = data.v2Circom.constraints;
    const reduction = data.v1Circom
      ? ((1 - v2 / data.v1Circom.constraints) * 100).toFixed(1)
      : '{---}';
    const states = data.v2Circom.states;
    const transitions = data.v2Circom.transitions;
    const escapedName = name.replace(/_/g, '\\_');
    lines.push(`${escapedName} & ${v1} & ${v2} & ${reduction} & ${states} & ${transitions} \\\\`);
  }

  lines.push('\\bottomrule');
  lines.push('\\end{tabular}');
  lines.push('\\end{table}');
  lines.push('');

  // Table 2: Proving times
  lines.push('% Table 2: Proving Time Comparison');
  lines.push('\\begin{table}[htbp]');
  lines.push('\\centering');
  lines.push('\\caption{Proving Time Comparison: Groth16 (Circom)}');
  lines.push('\\label{tab:proving}');
  lines.push('\\begin{tabular}{@{}l r r r@{}}');
  lines.push('\\toprule');
  lines.push('Pattern & v1 Prove (ms) & v2 Prove (ms) & Speedup \\\\');
  lines.push('\\midrule');

  for (const [name, data] of Object.entries(results.patterns)) {
    const v1Prove = data.v1Circom ? formatTimingLatex(data.v1Circom.proveMs) : '---';
    const v2Prove = formatTimingLatex(data.v2Circom.proveMs);
    const speedup = data.v1Circom
      ? `${(data.v1Circom.proveMs.mean / data.v2Circom.proveMs.mean).toFixed(2)}x`
      : '---';
    const escapedName = name.replace(/_/g, '\\_');
    lines.push(`${escapedName} & ${v1Prove} & ${v2Prove} & ${speedup} \\\\`);
  }

  lines.push('\\bottomrule');
  lines.push('\\end{tabular}');
  lines.push('\\end{table}');

  return lines.join('\n');
}

async function main() {
  console.log('Generating output files...\n');

  // Load results
  let results: BenchmarkResults;
  try {
    const content = await fs.readFile(RESULTS_FILE, 'utf-8');
    results = JSON.parse(content);
  } catch {
    console.error('No comparison.json found. Run `bun run collect` first.');
    process.exit(1);
  }

  // Ensure output directory exists
  await fs.mkdir(OUTPUT_DIR, { recursive: true });

  // Generate Markdown
  const markdown = generateMarkdown(results);
  const mdPath = path.join(OUTPUT_DIR, 'results.md');
  await fs.writeFile(mdPath, markdown);
  console.log(`Generated: ${mdPath}`);

  // Generate LaTeX
  const latex = generateLatex(results);
  const texPath = path.join(OUTPUT_DIR, 'tables.tex');
  await fs.writeFile(texPath, latex);
  console.log(`Generated: ${texPath}`);

  console.log('\nDone!');
}

main().catch((error) => {
  console.error('Error generating outputs:', error);
  process.exit(1);
});
