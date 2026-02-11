#!/usr/bin/env bun
/**
 * Generate output formats from benchmark results.
 *
 * Produces:
 * - outputs/results.md (Markdown tables)
 * - outputs/tables.tex (LaTeX tables for academic paper)
 *
 * LaTeX tables use booktabs + siunitx for professional formatting.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import type { BenchmarkResults, PatternBenchmark, TimingStats, ScalingDataPoint } from '../src/types.js';

const RESULTS_FILE = path.join(import.meta.dir, '..', 'results', 'comparison.json');
const OUTPUT_DIR = path.join(import.meta.dir, '..', 'outputs');

/**
 * Format timing stats with uncertainty for LaTeX (siunitx format).
 * Format: "mean +- stddev" for siunitx S columns.
 */
function formatTimingLatex(stats: TimingStats): string {
  if (stats.runs === 0) return '{---}';
  return `${stats.mean.toFixed(0)} +- ${stats.stddev.toFixed(0)}`;
}

/**
 * Format timing stats for Markdown.
 */
function formatTimingMarkdown(stats: TimingStats): string {
  if (stats.runs === 0) return '—';
  return `${stats.mean.toFixed(1)} ± ${stats.stddev.toFixed(1)}`;
}

/**
 * Format bytes for display (human-readable).
 */
function formatBytes(bytes: number): string {
  if (bytes === 0) return '—';
  if (bytes < 1024) return `${bytes}B`;
  return `${(bytes / 1024).toFixed(1)}KB`;
}

/**
 * Escape pattern name for LaTeX (underscores → \_).
 */
function escapeLatex(name: string): string {
  return name.replace(/_/g, '\\_').replace(/@/g, ' @ ');
}

/**
 * Extract pattern name from key (removes @inputLength suffix).
 */
function getPatternName(key: string): string {
  return key.split('@')[0];
}

/**
 * Extract input length from key.
 */
function getInputLength(key: string): number {
  const parts = key.split('@');
  return parts.length > 1 ? parseInt(parts[1], 10) : 0;
}

/**
 * Group patterns by base pattern name for summary tables.
 * Returns only entries at the default input length (64 bytes).
 */
function getDefaultInputPatterns(patterns: Record<string, PatternBenchmark>): [string, PatternBenchmark][] {
  return Object.entries(patterns)
    .filter(([key]) => key.endsWith('@64'))
    .sort(([a], [b]) => a.localeCompare(b));
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
    `- **Barretenberg**: ${results.toolVersions.barretenberg ?? 'N/A'}`,
    '',
  ];

  // Table 1: Constraint Count Comparison (64-byte input only)
  const defaultPatterns = getDefaultInputPatterns(results.patterns);
  if (defaultPatterns.length > 0) {
    lines.push('## Constraint Count Comparison (64-byte input)');
    lines.push('');
    lines.push('| Pattern | v1 (DFA) | v2 (NFA) | Reduction | v2 States | v2 Transitions |');
    lines.push('|---------|----------|----------|-----------|-----------|----------------|');

    for (const [key, data] of defaultPatterns) {
      const name = getPatternName(key);
      const v1 = data.v1Circom?.constraints ?? '—';
      const v2 = data.v2Circom.constraints || '—';
      const reduction = data.v1Circom && data.v2Circom.constraints
        ? `${((1 - data.v2Circom.constraints / data.v1Circom.constraints) * 100).toFixed(1)}%`
        : '—';
      const states = data.v2Circom.states || '—';
      const transitions = data.v2Circom.transitions || '—';
      lines.push(`| ${name} | ${v1} | ${v2} | ${reduction} | ${states} | ${transitions} |`);
    }
    lines.push('');
  }

  // Table 2: Proving Time Comparison (64-byte input only, v1 vs v2 Circom)
  const patternsWithV1 = defaultPatterns.filter(([, data]) => data.v1Circom);
  if (patternsWithV1.length > 0) {
    lines.push('## Proving Time Comparison (Circom/Groth16, 64-byte input)');
    lines.push('');
    lines.push('| Pattern | v1 Prove (ms) | v2 Prove (ms) | Speedup |');
    lines.push('|---------|---------------|---------------|---------|');

    for (const [key, data] of patternsWithV1) {
      const name = getPatternName(key);
      const v1Prove = formatTimingMarkdown(data.v1Circom!.proveMs);
      const v2Prove = data.v2Circom.proveMs.runs > 0
        ? formatTimingMarkdown(data.v2Circom.proveMs)
        : '—';
      const speedup = data.v2Circom.proveMs.runs > 0 && data.v1Circom!.proveMs.mean > 0
        ? `${(data.v1Circom!.proveMs.mean / data.v2Circom.proveMs.mean).toFixed(2)}x`
        : '—';
      lines.push(`| ${name} | ${v1Prove} | ${v2Prove} | ${speedup} |`);
    }
    lines.push('');
  }

  // Table 3: Noir Backend Performance (v2 only, 64-byte input)
  const patternsWithNoir = defaultPatterns.filter(([, data]) => data.v2Noir.backendGates > 0);
  if (patternsWithNoir.length > 0) {
    lines.push('## Noir Backend Performance (v2 only, 64-byte input)');
    lines.push('');
    lines.push('| Pattern | ACIR Opcodes | Backend Gates | Gates/Byte | Prove (ms) | Verify (ms) | Proof Size |');
    lines.push('|---------|--------------|---------------|------------|------------|-------------|------------|');

    for (const [key, data] of patternsWithNoir) {
      const name = getPatternName(key);
      const noir = data.v2Noir;
      lines.push(
        `| ${name} | ${noir.acirOpcodes} | ${noir.backendGates} | ${noir.gatesPerByte.toFixed(1)} | ${formatTimingMarkdown(noir.proveMs)} | ${formatTimingMarkdown(noir.verifyMs)} | ${formatBytes(noir.proofSizeBytes)} |`
      );
    }
    lines.push('');
  }

  // Table 4: Scaling Analysis
  if (results.scaling.length > 0) {
    lines.push('## Scaling by Input Length');
    lines.push('');
    lines.push('| Pattern | Input (bytes) | Circom R1CS | Noir Gates | Circom Prove (ms) | Noir Prove (ms) |');
    lines.push('|---------|---------------|-------------|------------|-------------------|-----------------|');

    for (const point of results.scaling) {
      const circomR1CS = point.circomConstraints || '—';
      const noirGates = point.noirGates || '—';
      const circomProve = point.circomProveMs > 0 ? point.circomProveMs.toFixed(0) : '—';
      const noirProve = point.noirProveMs > 0 ? point.noirProveMs.toFixed(0) : '—';
      lines.push(
        `| ${point.pattern} | ${point.inputLengthBytes} | ${circomR1CS} | ${noirGates} | ${circomProve} | ${noirProve} |`
      );
    }
    lines.push('');
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
    '% Generated: ' + results.hardware.timestamp,
    '',
  ];

  const defaultPatterns = getDefaultInputPatterns(results.patterns);

  // Table 1: R1CS Constraint Count Comparison
  if (defaultPatterns.length > 0) {
    lines.push('% Table 1: R1CS Constraint Count Comparison');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{R1CS Constraint Count Comparison: DFA-based (v1) vs NFA-based (v2) at 64-byte input}');
    lines.push('\\label{tab:constraints}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 6.0,');
    lines.push('  round-mode = places,');
    lines.push('  round-precision = 0,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l S S S[table-format=2.1] S[table-format=2.0] S[table-format=3.0]@{}}');
    lines.push('\\toprule');
    lines.push('\\multirow{2}{*}{Pattern} & \\multicolumn{2}{c}{Constraints} & {Reduction} & \\multicolumn{2}{c}{v2 Complexity} \\\\');
    lines.push('\\cmidrule(lr){2-3} \\cmidrule(l){5-6}');
    lines.push('& {v1 (DFA)} & {v2 (NFA)} & {(\\%)} & {States} & {Transitions} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of defaultPatterns) {
      const name = getPatternName(key);
      const v1 = data.v1Circom?.constraints ?? '{---}';
      const v2 = data.v2Circom.constraints || '{---}';
      const reduction = data.v1Circom && data.v2Circom.constraints
        ? ((1 - data.v2Circom.constraints / data.v1Circom.constraints) * 100).toFixed(1)
        : '{---}';
      const states = data.v2Circom.states || '{---}';
      const transitions = data.v2Circom.transitions || '{---}';
      lines.push(`${escapeLatex(name)} & ${v1} & ${v2} & ${reduction} & ${states} & ${transitions} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 2: Proving Time Comparison
  const patternsWithV1 = defaultPatterns.filter(([, data]) => data.v1Circom);
  if (patternsWithV1.length > 0) {
    lines.push('% Table 2: Proving Time Comparison');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Proving Time Comparison: Groth16 (Circom) at 64-byte input}');
    lines.push('\\label{tab:proving}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 4.0,');
    lines.push('  separate-uncertainty = true,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l');
    lines.push('  S[table-format=4.0(2)]');
    lines.push('  S[table-format=4.0(2)]');
    lines.push('  r@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {v1 Prove (ms)} & {v2 Prove (ms)} & Speedup \\\\');
    lines.push('\\midrule');

    for (const [key, data] of patternsWithV1) {
      const name = getPatternName(key);
      const v1Prove = formatTimingLatex(data.v1Circom!.proveMs);
      const v2Prove = data.v2Circom.proveMs.runs > 0 ? formatTimingLatex(data.v2Circom.proveMs) : '{---}';
      const speedup = data.v2Circom.proveMs.runs > 0 && data.v2Circom.proveMs.mean > 0
        ? `${(data.v1Circom!.proveMs.mean / data.v2Circom.proveMs.mean).toFixed(2)}\\times`
        : '---';
      lines.push(`${escapeLatex(name)} & ${v1Prove} & ${v2Prove} & ${speedup} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 3: Noir Backend Performance
  const patternsWithNoir = defaultPatterns.filter(([, data]) => data.v2Noir.backendGates > 0);
  if (patternsWithNoir.length > 0) {
    lines.push('% Table 3: Noir Backend Performance (v2 only)');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Noir Backend Performance (v2 only) at 64-byte input}');
    lines.push('\\label{tab:noir}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 5.0,');
    lines.push('  separate-uncertainty = true,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l');
    lines.push('  S[table-format=5.0]');  // ACIR Opcodes
    lines.push('  S[table-format=5.0]');  // Backend Gates
    lines.push('  S[table-format=4.1]');  // Gates/Byte
    lines.push('  S[table-format=3.0(2)]');  // Prove
    lines.push('  S[table-format=3.0(2)]');  // Verify
    lines.push('  S[table-format=5.0]@{}}');  // Proof Size
    lines.push('\\toprule');
    lines.push('Pattern & {ACIR Opcodes} & {Backend Gates} & {Gates/Byte} & {Prove (ms)} & {Verify (ms)} & {Proof (B)} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of patternsWithNoir) {
      const name = getPatternName(key);
      const noir = data.v2Noir;
      const proveMs = formatTimingLatex(noir.proveMs);
      const verifyMs = formatTimingLatex(noir.verifyMs);
      lines.push(`${escapeLatex(name)} & ${noir.acirOpcodes} & ${noir.backendGates} & ${noir.gatesPerByte.toFixed(1)} & ${proveMs} & ${verifyMs} & ${noir.proofSizeBytes} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 4: Scaling Analysis
  if (results.scaling.length > 0) {
    // Group scaling data by pattern for cleaner presentation
    const patternGroups = new Map<string, ScalingDataPoint[]>();
    for (const point of results.scaling) {
      if (!patternGroups.has(point.pattern)) {
        patternGroups.set(point.pattern, []);
      }
      patternGroups.get(point.pattern)!.push(point);
    }

    lines.push('% Table 4: Scaling by Input Length');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Circuit Size and Proving Time Scaling by Input Length}');
    lines.push('\\label{tab:scaling}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 5.0,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l');
    lines.push('  S[table-format=3.0]');   // Input (bytes)
    lines.push('  S[table-format=6.0]');   // Circom R1CS
    lines.push('  S[table-format=6.0]');   // Noir Gates
    lines.push('  S[table-format=4.0]');   // Circom Prove
    lines.push('  S[table-format=4.0]@{}}');  // Noir Prove
    lines.push('\\toprule');
    lines.push('Pattern & {Input (B)} & {Circom R1CS} & {Noir Gates} & {Circom (ms)} & {Noir (ms)} \\\\');
    lines.push('\\midrule');

    for (const [pattern, points] of patternGroups) {
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        const patternCol = i === 0 ? escapeLatex(pattern) : '';
        const circomR1CS = point.circomConstraints || '{---}';
        const noirGates = point.noirGates || '{---}';
        const circomProve = point.circomProveMs > 0 ? point.circomProveMs.toFixed(0) : '{---}';
        const noirProve = point.noirProveMs > 0 ? point.noirProveMs.toFixed(0) : '{---}';
        lines.push(`${patternCol} & ${point.inputLengthBytes} & ${circomR1CS} & ${noirGates} & ${circomProve} & ${noirProve} \\\\`);
      }
      // Add a small space between pattern groups
      lines.push('\\addlinespace');
    }

    // Remove last addlinespace
    lines.pop();

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
  }

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
