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
import type { BenchmarkResults, PatternBenchmark, TimingStats, ScalingDataPoint, MemoryStats, PhaseMemory } from '../src/types.js';

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
 * Format memory stats with uncertainty for LaTeX (siunitx format).
 */
function formatMemoryLatex(stats: MemoryStats | undefined): string {
  if (!stats || !stats.measured || stats.runs === 0) return '{---}';
  return `${stats.mean.toFixed(0)} +- ${stats.stddev.toFixed(0)}`;
}

/**
 * Format memory stats for Markdown.
 */
function formatMemoryMarkdown(stats: MemoryStats | undefined): string {
  if (!stats || !stats.measured || stats.runs === 0) return '—';
  return `${stats.mean.toFixed(0)} ± ${stats.stddev.toFixed(0)}`;
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
 * Escape control characters for Markdown display.
 */
function escapeForMarkdown(str: string): string {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/\|/g, '\\|')
    .replace(/\r/g, '\\r')
    .replace(/\n/g, '\\n')
    .replace(/`/g, '\\`');
}

/**
 * Escape special characters for LaTeX verbatim/texttt display.
 */
function escapeLatexVerbatim(str: string): string {
  return str
    .replace(/\\/g, '\\textbackslash{}')
    .replace(/\{/g, '\\{')
    .replace(/\}/g, '\\}')
    .replace(/_/g, '\\_')
    .replace(/\^/g, '\\textasciicircum{}')
    .replace(/~/g, '\\textasciitilde{}')
    .replace(/\$/g, '\\$')
    .replace(/%/g, '\\%')
    .replace(/&/g, '\\&')
    .replace(/#/g, '\\#')
    .replace(/\r/g, '\\textbackslash{}r')
    .replace(/\n/g, '\\textbackslash{}n');
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

  // Pattern Definitions table
  if (results.patternMetadata && Object.keys(results.patternMetadata).length > 0) {
    lines.push('## Pattern Definitions');
    lines.push('');
    lines.push('| Pattern | Regex | Sample Input |');
    lines.push('|---------|-------|--------------|');

    const sortedPatterns = Object.entries(results.patternMetadata).sort(([a], [b]) => a.localeCompare(b));
    for (const [pattern, meta] of sortedPatterns) {
      const escapedRegex = escapeForMarkdown(meta.regex);
      const escapedInput = escapeForMarkdown(meta.sampleInput);
      lines.push(`| ${pattern} | \`${escapedRegex}\` | \`${escapedInput}\` |`);
    }
    lines.push('');
  }

  // Table 1: Circuit Size Comparison - All Three Providers (64-byte input only)
  const defaultPatterns = getDefaultInputPatterns(results.patterns);
  if (defaultPatterns.length > 0) {
    lines.push('## Circuit Size Comparison (64-byte input)');
    lines.push('');
    lines.push('| Pattern | Circom v1 (DFA) | Circom v2 (NFA) | Noir v2 (UltraHonk) | v1→v2 Reduction |');
    lines.push('|---------|-----------------|-----------------|---------------------|-----------------|');

    for (const [key, data] of defaultPatterns) {
      const name = getPatternName(key);
      const v1 = data.v1Circom?.constraints ?? '—';
      const v2 = data.v2Circom.constraints || '—';
      const noir = data.v2Noir.backendGates || '—';
      const reduction = data.v1Circom && data.v2Circom.constraints
        ? `${((1 - data.v2Circom.constraints / data.v1Circom.constraints) * 100).toFixed(1)}%`
        : '—';
      lines.push(`| ${name} | ${v1} | ${v2} | ${noir} | ${reduction} |`);
    }
    lines.push('');
  }

  // Table 2: Proving Time Comparison - All Three Providers (64-byte input only)
  if (defaultPatterns.length > 0) {
    lines.push('## Proving Time Comparison (64-byte input)');
    lines.push('');
    lines.push('| Pattern | Circom v1 (ms) | Circom v2 (ms) | Noir v2 (ms) |');
    lines.push('|---------|----------------|----------------|--------------|');

    for (const [key, data] of defaultPatterns) {
      const name = getPatternName(key);
      const v1Prove = data.v1Circom ? formatTimingMarkdown(data.v1Circom.proveMs) : '—';
      const v2Prove = data.v2Circom.proveMs.runs > 0
        ? formatTimingMarkdown(data.v2Circom.proveMs)
        : '—';
      const noirProve = data.v2Noir.proveMs.runs > 0
        ? formatTimingMarkdown(data.v2Noir.proveMs)
        : '—';
      lines.push(`| ${name} | ${v1Prove} | ${v2Prove} | ${noirProve} |`);
    }
    lines.push('');
  }

  // Table 3: Noir v2 Backend Details (64-byte input)
  const patternsWithNoir = defaultPatterns.filter(([, data]) => data.v2Noir.backendGates > 0);
  if (patternsWithNoir.length > 0) {
    lines.push('## Noir v2 (UltraHonk) Backend Details (64-byte input)');
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

  // Table 4a: Scaling Circuit Size
  if (results.scaling.length > 0) {
    lines.push('## Scaling: Circuit Size by Input Length');
    lines.push('');
    lines.push('| Pattern | Input (bytes) | Circom v1 R1CS | Circom v2 R1CS | Noir v2 Gates |');
    lines.push('|---------|---------------|----------------|----------------|---------------|');

    for (const point of results.scaling) {
      const v1R1CS = point.circomV1Constraints ?? '—';
      const v2R1CS = point.circomV2Constraints || '—';
      const noirGates = point.noirGates || '—';
      lines.push(
        `| ${point.pattern} | ${point.inputLengthBytes} | ${v1R1CS} | ${v2R1CS} | ${noirGates} |`
      );
    }
    lines.push('');

    // Table 4b: Scaling Proving Time
    lines.push('## Scaling: Proving Time by Input Length');
    lines.push('');
    lines.push('| Pattern | Input (bytes) | Circom v1 (ms) | Circom v2 (ms) | Noir v2 (ms) |');
    lines.push('|---------|---------------|----------------|----------------|--------------|');

    for (const point of results.scaling) {
      const v1Prove = point.circomV1ProveMs && point.circomV1ProveMs > 0 ? point.circomV1ProveMs.toFixed(0) : '—';
      const v2Prove = point.circomV2ProveMs > 0 ? point.circomV2ProveMs.toFixed(0) : '—';
      const noirProve = point.noirProveMs > 0 ? point.noirProveMs.toFixed(0) : '—';
      lines.push(
        `| ${point.pattern} | ${point.inputLengthBytes} | ${v1Prove} | ${v2Prove} | ${noirProve} |`
      );
    }
    lines.push('');
  }

  // Table 5: Memory Usage by Phase - Circom v2
  if (defaultPatterns.length > 0) {
    const patternsWithMemory = defaultPatterns.filter(
      ([, data]) => data.v2Circom.memoryByPhase?.prove?.measured
    );
    if (patternsWithMemory.length > 0) {
      lines.push('## Memory Usage by Phase (MB) - Circom v2');
      lines.push('');
      lines.push('| Pattern | Compile | WitnessGen | Prove | Verify |');
      lines.push('|---------|---------|------------|-------|--------|');

      for (const [key, data] of patternsWithMemory) {
        const name = getPatternName(key);
        const mem = data.v2Circom.memoryByPhase;
        lines.push(
          `| ${name} | ${formatMemoryMarkdown(mem?.compile)} | ${formatMemoryMarkdown(mem?.witnessGen)} | ${formatMemoryMarkdown(mem?.prove)} | ${formatMemoryMarkdown(mem?.verify)} |`
        );
      }
      lines.push('');
    }
  }

  // Table 6: Memory Usage by Phase - Noir v2
  if (defaultPatterns.length > 0) {
    const patternsWithMemory = defaultPatterns.filter(
      ([, data]) => data.v2Noir.memoryByPhase?.prove?.measured
    );
    if (patternsWithMemory.length > 0) {
      lines.push('## Memory Usage by Phase (MB) - Noir v2');
      lines.push('');
      lines.push('| Pattern | Compile | WitnessGen | Prove | Verify |');
      lines.push('|---------|---------|------------|-------|--------|');

      for (const [key, data] of patternsWithMemory) {
        const name = getPatternName(key);
        const mem = data.v2Noir.memoryByPhase;
        lines.push(
          `| ${name} | ${formatMemoryMarkdown(mem?.compile)} | ${formatMemoryMarkdown(mem?.witnessGen)} | ${formatMemoryMarkdown(mem?.prove)} | ${formatMemoryMarkdown(mem?.verify)} |`
        );
      }
      lines.push('');
    }
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

  // Table 0: Pattern Definitions
  if (results.patternMetadata && Object.keys(results.patternMetadata).length > 0) {
    lines.push('% Table 0: Pattern Definitions');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Pattern Definitions and Sample Inputs}');
    lines.push('\\label{tab:patterns}');
    lines.push('\\begin{tabular}{@{}lp{0.4\\textwidth}p{0.35\\textwidth}@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & Regex & Sample Input \\\\');
    lines.push('\\midrule');

    const sortedPatterns = Object.entries(results.patternMetadata).sort(([a], [b]) => a.localeCompare(b));
    for (const [pattern, meta] of sortedPatterns) {
      const escapedPattern = escapeLatex(pattern);
      const escapedRegex = escapeLatexVerbatim(meta.regex);
      const escapedInput = escapeLatexVerbatim(meta.sampleInput);
      lines.push(`${escapedPattern} & \\texttt{${escapedRegex}} & \\texttt{${escapedInput}} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  const defaultPatterns = getDefaultInputPatterns(results.patterns);

  // Table 1: Circuit Size Comparison - All Three Providers
  if (defaultPatterns.length > 0) {
    lines.push('% Table 1: Circuit Size Comparison');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Circuit Size Comparison: Circom v1 (DFA), Circom v2 (NFA), and Noir v2 (UltraHonk) at 64-byte input}');
    lines.push('\\label{tab:circuit-size}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 6.0,');
    lines.push('  round-mode = places,');
    lines.push('  round-precision = 0,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l S S S S[table-format=2.1]@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {Circom v1 (DFA)} & {Circom v2 (NFA)} & {Noir v2} & {v1$\\rightarrow$v2 (\\%)} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of defaultPatterns) {
      const name = getPatternName(key);
      const v1 = data.v1Circom?.constraints ?? '{---}';
      const v2 = data.v2Circom.constraints || '{---}';
      const noir = data.v2Noir.backendGates || '{---}';
      const reduction = data.v1Circom && data.v2Circom.constraints
        ? ((1 - data.v2Circom.constraints / data.v1Circom.constraints) * 100).toFixed(1)
        : '{---}';
      lines.push(`${escapeLatex(name)} & ${v1} & ${v2} & ${noir} & ${reduction} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 2: Proving Time Comparison - All Three Providers
  if (defaultPatterns.length > 0) {
    lines.push('% Table 2: Proving Time Comparison');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Proving Time Comparison: Circom v1/v2 (Groth16) and Noir v2 (UltraHonk) at 64-byte input}');
    lines.push('\\label{tab:proving}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 4.0,');
    lines.push('  separate-uncertainty = true,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l');
    lines.push('  S[table-format=4.0(2)]');
    lines.push('  S[table-format=4.0(2)]');
    lines.push('  S[table-format=4.0(2)]@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {Circom v1 (ms)} & {Circom v2 (ms)} & {Noir v2 (ms)} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of defaultPatterns) {
      const name = getPatternName(key);
      const v1Prove = data.v1Circom ? formatTimingLatex(data.v1Circom.proveMs) : '{---}';
      const v2Prove = data.v2Circom.proveMs.runs > 0 ? formatTimingLatex(data.v2Circom.proveMs) : '{---}';
      const noirProve = data.v2Noir.proveMs.runs > 0 ? formatTimingLatex(data.v2Noir.proveMs) : '{---}';
      lines.push(`${escapeLatex(name)} & ${v1Prove} & ${v2Prove} & ${noirProve} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 3: Noir v2 Backend Details
  const patternsWithNoir = defaultPatterns.filter(([, data]) => data.v2Noir.backendGates > 0);
  if (patternsWithNoir.length > 0) {
    lines.push('% Table 3: Noir v2 (UltraHonk) Backend Details');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Noir v2 (UltraHonk) Backend Details at 64-byte input}');
    lines.push('\\label{tab:noir-details}');
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

  // Table 4a: Scaling Circuit Size
  if (results.scaling.length > 0) {
    // Group scaling data by pattern for cleaner presentation
    const patternGroups = new Map<string, ScalingDataPoint[]>();
    for (const point of results.scaling) {
      if (!patternGroups.has(point.pattern)) {
        patternGroups.set(point.pattern, []);
      }
      patternGroups.get(point.pattern)!.push(point);
    }

    lines.push('% Table 4a: Circuit Size Scaling by Input Length');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Circuit Size Scaling by Input Length}');
    lines.push('\\label{tab:scaling-size}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 6.0,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l');
    lines.push('  S[table-format=3.0]');   // Input (bytes)
    lines.push('  S[table-format=6.0]');   // Circom v1 R1CS
    lines.push('  S[table-format=6.0]');   // Circom v2 R1CS
    lines.push('  S[table-format=6.0]@{}}');   // Noir Gates
    lines.push('\\toprule');
    lines.push('Pattern & {Input (B)} & {Circom v1 R1CS} & {Circom v2 R1CS} & {Noir v2 Gates} \\\\');
    lines.push('\\midrule');

    for (const [pattern, points] of patternGroups) {
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        const patternCol = i === 0 ? escapeLatex(pattern) : '';
        const v1R1CS = point.circomV1Constraints ?? '{---}';
        const v2R1CS = point.circomV2Constraints || '{---}';
        const noirGates = point.noirGates || '{---}';
        lines.push(`${patternCol} & ${point.inputLengthBytes} & ${v1R1CS} & ${v2R1CS} & ${noirGates} \\\\`);
      }
      lines.push('\\addlinespace');
    }

    // Remove last addlinespace
    lines.pop();

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');

    // Table 4b: Proving Time Scaling
    lines.push('% Table 4b: Proving Time Scaling by Input Length');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Proving Time Scaling by Input Length}');
    lines.push('\\label{tab:scaling-time}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 4.0,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l');
    lines.push('  S[table-format=3.0]');   // Input (bytes)
    lines.push('  S[table-format=4.0]');   // Circom v1 Prove
    lines.push('  S[table-format=4.0]');   // Circom v2 Prove
    lines.push('  S[table-format=4.0]@{}}');  // Noir Prove
    lines.push('\\toprule');
    lines.push('Pattern & {Input (B)} & {Circom v1 (ms)} & {Circom v2 (ms)} & {Noir v2 (ms)} \\\\');
    lines.push('\\midrule');

    for (const [pattern, points] of patternGroups) {
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        const patternCol = i === 0 ? escapeLatex(pattern) : '';
        const v1Prove = point.circomV1ProveMs && point.circomV1ProveMs > 0 ? point.circomV1ProveMs.toFixed(0) : '{---}';
        const v2Prove = point.circomV2ProveMs > 0 ? point.circomV2ProveMs.toFixed(0) : '{---}';
        const noirProve = point.noirProveMs > 0 ? point.noirProveMs.toFixed(0) : '{---}';
        lines.push(`${patternCol} & ${point.inputLengthBytes} & ${v1Prove} & ${v2Prove} & ${noirProve} \\\\`);
      }
      lines.push('\\addlinespace');
    }

    // Remove last addlinespace
    lines.pop();

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
  }

  // Table 5: Memory Usage by Phase - Circom v2
  const patternsWithCircomMemory = defaultPatterns.filter(
    ([, data]) => data.v2Circom.memoryByPhase?.prove?.measured
  );
  if (patternsWithCircomMemory.length > 0) {
    lines.push('');
    lines.push('% Table 5: Memory Usage by Phase - Circom v2');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Memory Usage by Phase (MB) - Circom v2 at 64-byte input}');
    lines.push('\\label{tab:memory-circom}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 4.0,');
    lines.push('  separate-uncertainty = true,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l');
    lines.push('  S[table-format=4.0(2)]');  // Compile
    lines.push('  S[table-format=4.0(2)]');  // WitnessGen
    lines.push('  S[table-format=4.0(2)]');  // Prove
    lines.push('  S[table-format=3.0(2)]@{}}');  // Verify
    lines.push('\\toprule');
    lines.push('Pattern & {Compile (MB)} & {WitnessGen (MB)} & {Prove (MB)} & {Verify (MB)} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of patternsWithCircomMemory) {
      const name = getPatternName(key);
      const mem = data.v2Circom.memoryByPhase;
      lines.push(`${escapeLatex(name)} & ${formatMemoryLatex(mem?.compile)} & ${formatMemoryLatex(mem?.witnessGen)} & ${formatMemoryLatex(mem?.prove)} & ${formatMemoryLatex(mem?.verify)} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
  }

  // Table 6: Memory Usage by Phase - Noir v2
  const patternsWithNoirMemory = defaultPatterns.filter(
    ([, data]) => data.v2Noir.memoryByPhase?.prove?.measured
  );
  if (patternsWithNoirMemory.length > 0) {
    lines.push('');
    lines.push('% Table 6: Memory Usage by Phase - Noir v2');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Memory Usage by Phase (MB) - Noir v2 at 64-byte input}');
    lines.push('\\label{tab:memory-noir}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 4.0,');
    lines.push('  separate-uncertainty = true,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}l');
    lines.push('  S[table-format=4.0(2)]');  // Compile
    lines.push('  S[table-format=4.0(2)]');  // WitnessGen
    lines.push('  S[table-format=4.0(2)]');  // Prove
    lines.push('  S[table-format=3.0(2)]@{}}');  // Verify
    lines.push('\\toprule');
    lines.push('Pattern & {Compile (MB)} & {WitnessGen (MB)} & {Prove (MB)} & {Verify (MB)} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of patternsWithNoirMemory) {
      const name = getPatternName(key);
      const mem = data.v2Noir.memoryByPhase;
      lines.push(`${escapeLatex(name)} & ${formatMemoryLatex(mem?.compile)} & ${formatMemoryLatex(mem?.witnessGen)} & ${formatMemoryLatex(mem?.prove)} & ${formatMemoryLatex(mem?.verify)} \\\\`);
    }

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
