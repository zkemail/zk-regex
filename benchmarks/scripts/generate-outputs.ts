#!/usr/bin/env bun
/**
 * Generate output formats from benchmark results.
 *
 * Produces:
 * - outputs/results.md (Markdown tables)
 * - outputs/tables.tex (LaTeX tables for academic paper)
 *
 * Output structure:
 * 1. Pattern Definitions (with complexity and features)
 * 2. V1 vs V2 Comparison (grouped by complexity - PRIMARY)
 * 3. V1 Compatibility Analysis (failure modes)
 * 4. V2-Only Patterns (features v1 cannot compile)
 * 5. Scaling Analysis by Complexity
 * 6. Summary Statistics
 * 7. Noir v2 Details (separate section)
 * 8. Memory Usage
 *
 * LaTeX tables use booktabs + siunitx for professional formatting.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import type {
  BenchmarkResults,
  PatternBenchmark,
  TimingStats,
  ScalingDataPoint,
  MemoryStats,
  PatternDefinition,
  PatternComplexity,
} from '../src/types.js';

const RESULTS_FILE = path.join(import.meta.dir, '..', 'results', 'comparison.json');
const PATTERNS_FILE = path.join(import.meta.dir, '..', 'config', 'patterns.json');
const V1_COMPAT_FILE = path.join(import.meta.dir, '..', 'results', 'v1-compatibility.json');
const OUTPUT_DIR = path.join(import.meta.dir, '..', 'outputs');

// --- Formatting helpers ---

function formatTimingLatex(stats: TimingStats): string {
  if (stats.runs === 0) return '{---}';
  return `${stats.mean.toFixed(0)} +- ${stats.stddev.toFixed(0)}`;
}

function formatTimingMarkdown(stats: TimingStats): string {
  if (stats.runs === 0) return '—';
  return `${stats.mean.toFixed(1)} ± ${stats.stddev.toFixed(1)}`;
}

function formatMemoryLatex(stats: MemoryStats | undefined): string {
  if (!stats || !stats.measured || stats.runs === 0) return '{---}';
  return `${stats.mean.toFixed(0)} +- ${stats.stddev.toFixed(0)}`;
}

function formatMemoryMarkdown(stats: MemoryStats | undefined): string {
  if (!stats || !stats.measured || stats.runs === 0) return '—';
  return `${stats.mean.toFixed(0)} ± ${stats.stddev.toFixed(0)}`;
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '—';
  if (bytes < 1024) return `${bytes}B`;
  return `${(bytes / 1024).toFixed(1)}KB`;
}

function escapeLatex(name: string): string {
  return name.replace(/_/g, '\\_').replace(/@/g, ' @ ');
}

function escapeForMarkdown(str: string): string {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/\|/g, '\\|')
    .replace(/\r/g, '\\r')
    .replace(/\n/g, '\\n')
    .replace(/`/g, '\\`');
}

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

function getPatternName(key: string): string {
  return key.split('@')[0];
}

function getInputLength(key: string): number {
  const parts = key.split('@');
  return parts.length > 1 ? parseInt(parts[1], 10) : 0;
}

// --- Data grouping helpers ---

interface PatternDefMap {
  [name: string]: PatternDefinition;
}

interface V1CompatEntry {
  pattern: string;
  v1CompilerResult: string;
  v1CompilerPhase: string | null;
  v1CompilerError: string | null;
  circomCompileResult: string;
  circomCompileError: string | null;
  availableInV1: boolean;
  notes: string;
}

const COMPLEXITY_ORDER: PatternComplexity[] = ['simple', 'medium', 'complex', 'v2-only'];

function getDefaultInputPatterns(patterns: Record<string, PatternBenchmark>): [string, PatternBenchmark][] {
  return Object.entries(patterns)
    .filter(([key]) => key.endsWith('@64'))
    .sort(([a], [b]) => a.localeCompare(b));
}

/**
 * Group default-input patterns by complexity level.
 */
function groupByComplexity(
  defaultPatterns: [string, PatternBenchmark][],
  patternDefs: PatternDefMap,
): Map<PatternComplexity, [string, PatternBenchmark][]> {
  const groups = new Map<PatternComplexity, [string, PatternBenchmark][]>();
  for (const level of COMPLEXITY_ORDER) {
    groups.set(level, []);
  }

  for (const entry of defaultPatterns) {
    const name = getPatternName(entry[0]);
    const def = patternDefs[name];
    const level = def?.complexity ?? 'complex';
    groups.get(level)!.push(entry);
  }

  return groups;
}

/**
 * Compute reduction percentage.
 */
function reductionPct(v1: number, v2: number): string {
  if (!v1 || !v2) return '—';
  return `${((1 - v2 / v1) * 100).toFixed(1)}%`;
}

// --- Markdown Generator ---

function generateMarkdown(
  results: BenchmarkResults,
  patternDefs: PatternDefMap,
  v1Compat: V1CompatEntry[],
): string {
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

  // Pattern Definitions with complexity and features
  const defEntries = Object.values(patternDefs).sort((a, b) => a.name.localeCompare(b.name));
  if (defEntries.length > 0) {
    lines.push('## Pattern Definitions');
    lines.push('');
    lines.push('| Pattern | Complexity | Category | Features | Regex | Sample Input |');
    lines.push('|---------|-----------|----------|----------|-------|--------------|');

    for (const def of defEntries) {
      const escapedRegex = escapeForMarkdown(def.regex);
      const escapedInput = escapeForMarkdown(def.sampleInput);
      const features = def.features.join(', ');
      lines.push(`| ${def.name} | ${def.complexity} | ${def.category} | ${features} | \`${escapedRegex}\` | \`${escapedInput}\` |`);
    }
    lines.push('');
  }

  // V1 vs V2 Comparison (PRIMARY) - grouped by complexity
  const defaultPatterns = getDefaultInputPatterns(results.patterns);
  const grouped = groupByComplexity(defaultPatterns, patternDefs);

  if (defaultPatterns.length > 0) {
    lines.push('## V1 vs V2 Comparison (64-byte input)');
    lines.push('');

    for (const level of COMPLEXITY_ORDER) {
      const entries = grouped.get(level)!;
      // Only show patterns that have v1 data for comparison sections
      const withV1 = entries.filter(([, data]) => data.v1Circom != null);
      if (withV1.length === 0 && level !== 'v2-only') continue;
      if (level === 'v2-only') continue; // V2-only gets its own section

      lines.push(`### ${level.charAt(0).toUpperCase() + level.slice(1)} Patterns`);
      lines.push('');
      lines.push('| Pattern | V1 Constraints | V2 Constraints | Reduction | V1 Prove (ms) | V2 Prove (ms) |');
      lines.push('|---------|----------------|----------------|-----------|---------------|---------------|');

      for (const [key, data] of withV1) {
        const name = getPatternName(key);
        const v1c = data.v1Circom!.constraints;
        const v2c = data.v2Circom.constraints;
        lines.push(
          `| ${name} | ${v1c} | ${v2c} | ${reductionPct(v1c, v2c)} | ${formatTimingMarkdown(data.v1Circom!.proveMs)} | ${formatTimingMarkdown(data.v2Circom.proveMs)} |`
        );
      }
      lines.push('');
    }
  }

  // V1 Compatibility Analysis
  if (v1Compat.length > 0) {
    lines.push('## V1 Compatibility Analysis');
    lines.push('');
    lines.push('| Pattern | Complexity | V1 Compiler | Circom Compile | Failure Phase | Error Summary |');
    lines.push('|---------|-----------|-------------|----------------|---------------|---------------|');

    for (const entry of v1Compat) {
      const def = patternDefs[entry.pattern];
      const complexity = def?.complexity ?? '?';
      const failPhase = entry.v1CompilerPhase ?? '—';
      const errorSummary = entry.v1CompilerError ? entry.v1CompilerError.substring(0, 50) : '—';
      lines.push(
        `| ${entry.pattern} | ${complexity} | ${entry.v1CompilerResult} | ${entry.circomCompileResult} | ${failPhase} | ${errorSummary} |`
      );
    }
    lines.push('');
  }

  // V2-Only Patterns (those without v1 data)
  const v2OnlyPatterns = defaultPatterns.filter(([, data]) => data.v1Circom == null);
  if (v2OnlyPatterns.length > 0) {
    lines.push('## V2-Only Patterns');
    lines.push('');
    lines.push('| Pattern | V2 Constraints | V2 Prove (ms) | Noir Gates | Features |');
    lines.push('|---------|----------------|---------------|------------|----------|');

    for (const [key, data] of v2OnlyPatterns) {
      const name = getPatternName(key);
      const def = patternDefs[name];
      const features = def?.features.join(', ') ?? '';
      lines.push(
        `| ${name} | ${data.v2Circom.constraints} | ${formatTimingMarkdown(data.v2Circom.proveMs)} | ${data.v2Noir.backendGates || '—'} | ${features} |`
      );
    }
    lines.push('');
  }

  // Scaling Analysis by Complexity
  if (results.scaling.length > 0) {
    lines.push('## Scaling: Circuit Size by Input Length');
    lines.push('');
    lines.push('| Pattern | Complexity | Input (bytes) | Circom v1 R1CS | Circom v2 R1CS | Noir v2 Gates |');
    lines.push('|---------|-----------|---------------|----------------|----------------|---------------|');

    for (const point of results.scaling) {
      const def = patternDefs[point.pattern];
      const complexity = def?.complexity ?? '?';
      const v1R1CS = point.circomV1Constraints ?? '—';
      const v2R1CS = point.circomV2Constraints || '—';
      const noirGates = point.noirGates || '—';
      lines.push(
        `| ${point.pattern} | ${complexity} | ${point.inputLengthBytes} | ${v1R1CS} | ${v2R1CS} | ${noirGates} |`
      );
    }
    lines.push('');

    lines.push('## Scaling: Proving Time by Input Length');
    lines.push('');
    lines.push('| Pattern | Complexity | Input (bytes) | Circom v1 (ms) | Circom v2 (ms) | Noir v2 (ms) |');
    lines.push('|---------|-----------|---------------|----------------|----------------|--------------|');

    for (const point of results.scaling) {
      const def = patternDefs[point.pattern];
      const complexity = def?.complexity ?? '?';
      const v1Prove = point.circomV1ProveMs && point.circomV1ProveMs > 0 ? point.circomV1ProveMs.toFixed(0) : '—';
      const v2Prove = point.circomV2ProveMs > 0 ? point.circomV2ProveMs.toFixed(0) : '—';
      const noirProve = point.noirProveMs > 0 ? point.noirProveMs.toFixed(0) : '—';
      lines.push(
        `| ${point.pattern} | ${complexity} | ${point.inputLengthBytes} | ${v1Prove} | ${v2Prove} | ${noirProve} |`
      );
    }
    lines.push('');
  }

  // Summary Statistics
  if (defaultPatterns.length > 0) {
    lines.push('## Summary Statistics');
    lines.push('');
    lines.push('| Complexity | Patterns | Avg V1 Constraints | Avg V2 Constraints | Avg Reduction | Notes |');
    lines.push('|-----------|----------|--------------------|--------------------|---------------|-------|');

    for (const level of COMPLEXITY_ORDER) {
      const entries = grouped.get(level)!;
      if (entries.length === 0) continue;
      const withV1 = entries.filter(([, d]) => d.v1Circom != null);
      const avgV1 = withV1.length > 0
        ? Math.round(withV1.reduce((s, [, d]) => s + d.v1Circom!.constraints, 0) / withV1.length)
        : '—';
      const avgV2 = Math.round(entries.reduce((s, [, d]) => s + d.v2Circom.constraints, 0) / entries.length);
      const avgReduction = withV1.length > 0
        ? ((1 - entries.reduce((s, [, d]) => s + d.v2Circom.constraints, 0) / withV1.reduce((s, [, d]) => s + d.v1Circom!.constraints, 0)) * 100).toFixed(1) + '%'
        : '—';
      const v2Only = entries.length - withV1.length;
      const notes = v2Only > 0 ? `${v2Only} v2-only` : `${withV1.length} compared`;
      lines.push(`| ${level} | ${entries.length} | ${avgV1} | ${avgV2} | ${avgReduction} | ${notes} |`);
    }
    lines.push('');
  }

  // Noir v2 Details (separate section)
  const patternsWithNoir = defaultPatterns.filter(([, data]) => data.v2Noir.backendGates > 0);
  if (patternsWithNoir.length > 0) {
    lines.push('## Noir v2 (UltraHonk) Backend Details (64-byte input)');
    lines.push('');
    lines.push('| Pattern | Complexity | ACIR Opcodes | Backend Gates | Gates/Byte | Prove (ms) | Verify (ms) | Proof Size |');
    lines.push('|---------|-----------|--------------|---------------|------------|------------|-------------|------------|');

    for (const [key, data] of patternsWithNoir) {
      const name = getPatternName(key);
      const def = patternDefs[name];
      const complexity = def?.complexity ?? '?';
      const noir = data.v2Noir;
      lines.push(
        `| ${name} | ${complexity} | ${noir.acirOpcodes} | ${noir.backendGates} | ${noir.gatesPerByte.toFixed(1)} | ${formatTimingMarkdown(noir.proveMs)} | ${formatTimingMarkdown(noir.verifyMs)} | ${formatBytes(noir.proofSizeBytes)} |`
      );
    }
    lines.push('');
  }

  // Memory Usage - Circom v2
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

  // Memory Usage - Noir v2
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

// --- LaTeX Generator ---

function generateLatex(
  results: BenchmarkResults,
  patternDefs: PatternDefMap,
  v1Compat: V1CompatEntry[],
): string {
  const lines: string[] = [
    '% ZK-Regex Benchmark Tables',
    '% Requires: booktabs, siunitx, multirow packages',
    '% Generated: ' + results.hardware.timestamp,
    '',
  ];

  const defEntries = Object.values(patternDefs).sort((a, b) => a.name.localeCompare(b.name));
  const defaultPatterns = getDefaultInputPatterns(results.patterns);
  const grouped = groupByComplexity(defaultPatterns, patternDefs);

  // Table 0: Pattern Definitions with complexity
  if (defEntries.length > 0) {
    lines.push('% Table 0: Pattern Definitions');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Pattern Definitions with Complexity Classification}');
    lines.push('\\label{tab:patterns}');
    lines.push('\\begin{tabular}{@{}llllp{0.25\\textwidth}@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & Complexity & Category & Features & Regex \\\\');
    lines.push('\\midrule');

    for (const def of defEntries) {
      const escapedRegex = escapeLatexVerbatim(def.regex);
      const features = def.features.slice(0, 2).join(', ').replace(/_/g, '\\_');
      lines.push(`${escapeLatex(def.name)} & ${def.complexity} & ${def.category} & ${features} & \\texttt{${escapedRegex}} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 1: V1 vs V2 Comparison (PRIMARY) - grouped by complexity
  if (defaultPatterns.length > 0) {
    lines.push('% Table 1: V1 vs V2 Circuit Size Comparison (grouped by complexity)');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{V1 (DFA) vs V2 (NFA) Circuit Size Comparison at 64-byte input}');
    lines.push('\\label{tab:v1v2-comparison}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 6.0,');
    lines.push('  round-mode = places,');
    lines.push('  round-precision = 0,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}ll S S S[table-format=2.1] S[table-format=4.0(2)] S[table-format=4.0(2)]@{}}');
    lines.push('\\toprule');
    lines.push('Complexity & Pattern & {V1 R1CS} & {V2 R1CS} & {Reduction (\\%)} & {V1 Prove (ms)} & {V2 Prove (ms)} \\\\');
    lines.push('\\midrule');

    for (const level of COMPLEXITY_ORDER) {
      if (level === 'v2-only') continue;
      const entries = grouped.get(level)!.filter(([, d]) => d.v1Circom != null);
      if (entries.length === 0) continue;

      for (let i = 0; i < entries.length; i++) {
        const [key, data] = entries[i];
        const name = getPatternName(key);
        const levelCol = i === 0 ? level : '';
        const v1c = data.v1Circom!.constraints;
        const v2c = data.v2Circom.constraints;
        const red = v1c > 0 ? ((1 - v2c / v1c) * 100).toFixed(1) : '{---}';
        lines.push(`${levelCol} & ${escapeLatex(name)} & ${v1c} & ${v2c} & ${red} & ${formatTimingLatex(data.v1Circom!.proveMs)} & ${formatTimingLatex(data.v2Circom.proveMs)} \\\\`);
      }
      lines.push('\\addlinespace');
    }

    // Remove last addlinespace
    if (lines[lines.length - 1] === '\\addlinespace') lines.pop();

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 2: V1 Compatibility Analysis
  if (v1Compat.length > 0) {
    lines.push('% Table 2: V1 Compatibility Analysis');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{V1 DFA Compiler Compatibility Analysis}');
    lines.push('\\label{tab:v1-compat}');
    lines.push('\\begin{tabular}{@{}llllp{0.3\\textwidth}@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & Complexity & V1 Compiler & Circom & Notes \\\\');
    lines.push('\\midrule');

    for (const entry of v1Compat) {
      const def = patternDefs[entry.pattern];
      const complexity = def?.complexity ?? '?';
      const notes = escapeLatexVerbatim(entry.notes.substring(0, 60));
      lines.push(`${escapeLatex(entry.pattern)} & ${complexity} & ${entry.v1CompilerResult} & ${entry.circomCompileResult} & ${notes} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 3: V2-Only patterns
  const v2OnlyPatterns = defaultPatterns.filter(([, d]) => d.v1Circom == null);
  if (v2OnlyPatterns.length > 0) {
    lines.push('% Table 3: V2-Only Patterns');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{V2-Only Patterns (V1 DFA cannot compile)}');
    lines.push('\\label{tab:v2-only}');
    lines.push('\\sisetup{table-format = 5.0, separate-uncertainty = true}');
    lines.push('\\begin{tabular}{@{}l S S[table-format=4.0(2)] S@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {V2 R1CS} & {V2 Prove (ms)} & {Noir Gates} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of v2OnlyPatterns) {
      const name = getPatternName(key);
      lines.push(`${escapeLatex(name)} & ${data.v2Circom.constraints} & ${formatTimingLatex(data.v2Circom.proveMs)} & ${data.v2Noir.backendGates || '{---}'} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 4: Scaling by input length
  if (results.scaling.length > 0) {
    const patternGroups = new Map<string, ScalingDataPoint[]>();
    for (const point of results.scaling) {
      if (!patternGroups.has(point.pattern)) {
        patternGroups.set(point.pattern, []);
      }
      patternGroups.get(point.pattern)!.push(point);
    }

    lines.push('% Table 4a: Circuit Size Scaling');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Circuit Size Scaling by Input Length}');
    lines.push('\\label{tab:scaling-size}');
    lines.push('\\sisetup{table-format = 6.0}');
    lines.push('\\begin{tabular}{@{}ll S[table-format=3.0] S S S@{}}');
    lines.push('\\toprule');
    lines.push('Complexity & Pattern & {Input (B)} & {V1 R1CS} & {V2 R1CS} & {Noir Gates} \\\\');
    lines.push('\\midrule');

    for (const [pattern, points] of patternGroups) {
      const def = patternDefs[pattern];
      const complexity = def?.complexity ?? '?';
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        const complexCol = i === 0 ? complexity : '';
        const patternCol = i === 0 ? escapeLatex(pattern) : '';
        lines.push(`${complexCol} & ${patternCol} & ${point.inputLengthBytes} & ${point.circomV1Constraints ?? '{---}'} & ${point.circomV2Constraints || '{---}'} & ${point.noirGates || '{---}'} \\\\`);
      }
      lines.push('\\addlinespace');
    }
    if (lines[lines.length - 1] === '\\addlinespace') lines.pop();

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');

    // Table 4b: Proving Time Scaling
    lines.push('% Table 4b: Proving Time Scaling');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Proving Time Scaling by Input Length}');
    lines.push('\\label{tab:scaling-time}');
    lines.push('\\sisetup{table-format = 4.0}');
    lines.push('\\begin{tabular}{@{}ll S[table-format=3.0] S S S@{}}');
    lines.push('\\toprule');
    lines.push('Complexity & Pattern & {Input (B)} & {V1 (ms)} & {V2 (ms)} & {Noir (ms)} \\\\');
    lines.push('\\midrule');

    for (const [pattern, points] of patternGroups) {
      const def = patternDefs[pattern];
      const complexity = def?.complexity ?? '?';
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        const complexCol = i === 0 ? complexity : '';
        const patternCol = i === 0 ? escapeLatex(pattern) : '';
        const v1Prove = point.circomV1ProveMs && point.circomV1ProveMs > 0 ? point.circomV1ProveMs.toFixed(0) : '{---}';
        const v2Prove = point.circomV2ProveMs > 0 ? point.circomV2ProveMs.toFixed(0) : '{---}';
        const noirProve = point.noirProveMs > 0 ? point.noirProveMs.toFixed(0) : '{---}';
        lines.push(`${complexCol} & ${patternCol} & ${point.inputLengthBytes} & ${v1Prove} & ${v2Prove} & ${noirProve} \\\\`);
      }
      lines.push('\\addlinespace');
    }
    if (lines[lines.length - 1] === '\\addlinespace') lines.pop();

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 5: Summary Statistics
  if (defaultPatterns.length > 0) {
    lines.push('% Table 5: Summary Statistics by Complexity');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Summary Statistics by Complexity Level at 64-byte input}');
    lines.push('\\label{tab:summary}');
    lines.push('\\sisetup{table-format = 6.0}');
    lines.push('\\begin{tabular}{@{}l S[table-format=2.0] S S S[table-format=2.1]@{}}');
    lines.push('\\toprule');
    lines.push('Complexity & {Patterns} & {Avg V1 R1CS} & {Avg V2 R1CS} & {Avg Reduction (\\%)} \\\\');
    lines.push('\\midrule');

    for (const level of COMPLEXITY_ORDER) {
      const entries = grouped.get(level)!;
      if (entries.length === 0) continue;
      const withV1 = entries.filter(([, d]) => d.v1Circom != null);
      const avgV1 = withV1.length > 0
        ? Math.round(withV1.reduce((s, [, d]) => s + d.v1Circom!.constraints, 0) / withV1.length)
        : '{---}';
      const avgV2 = Math.round(entries.reduce((s, [, d]) => s + d.v2Circom.constraints, 0) / entries.length);
      const avgReduction = withV1.length > 0 && typeof avgV1 === 'number'
        ? ((1 - avgV2 / avgV1) * 100).toFixed(1)
        : '{---}';
      lines.push(`${level} & ${entries.length} & ${avgV1} & ${avgV2} & ${avgReduction} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 6: Noir v2 Details (separate section)
  const patternsWithNoir = defaultPatterns.filter(([, data]) => data.v2Noir.backendGates > 0);
  if (patternsWithNoir.length > 0) {
    lines.push('% Table 6: Noir v2 Backend Details');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Noir v2 (UltraHonk) Backend Details at 64-byte input}');
    lines.push('\\label{tab:noir-details}');
    lines.push('\\sisetup{table-format = 5.0, separate-uncertainty = true}');
    lines.push('\\begin{tabular}{@{}ll');
    lines.push('  S[table-format=5.0]');
    lines.push('  S[table-format=5.0]');
    lines.push('  S[table-format=4.1]');
    lines.push('  S[table-format=3.0(2)]');
    lines.push('  S[table-format=3.0(2)]');
    lines.push('  S[table-format=5.0]@{}}');
    lines.push('\\toprule');
    lines.push('Complexity & Pattern & {ACIR} & {Gates} & {Gates/B} & {Prove (ms)} & {Verify (ms)} & {Proof (B)} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of patternsWithNoir) {
      const name = getPatternName(key);
      const def = patternDefs[name];
      const complexity = def?.complexity ?? '?';
      const noir = data.v2Noir;
      lines.push(`${complexity} & ${escapeLatex(name)} & ${noir.acirOpcodes} & ${noir.backendGates} & ${noir.gatesPerByte.toFixed(1)} & ${formatTimingLatex(noir.proveMs)} & ${formatTimingLatex(noir.verifyMs)} & ${noir.proofSizeBytes} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 7/8: Memory Usage
  const patternsWithCircomMemory = defaultPatterns.filter(
    ([, data]) => data.v2Circom.memoryByPhase?.prove?.measured
  );
  if (patternsWithCircomMemory.length > 0) {
    lines.push('% Table 7: Memory Usage - Circom v2');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Memory Usage by Phase (MB) - Circom v2 at 64-byte input}');
    lines.push('\\label{tab:memory-circom}');
    lines.push('\\sisetup{table-format = 4.0, separate-uncertainty = true}');
    lines.push('\\begin{tabular}{@{}l S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=3.0(2)]@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {Compile} & {WitnessGen} & {Prove} & {Verify} \\\\');
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

  const patternsWithNoirMemory = defaultPatterns.filter(
    ([, data]) => data.v2Noir.memoryByPhase?.prove?.measured
  );
  if (patternsWithNoirMemory.length > 0) {
    lines.push('');
    lines.push('% Table 8: Memory Usage - Noir v2');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Memory Usage by Phase (MB) - Noir v2 at 64-byte input}');
    lines.push('\\label{tab:memory-noir}');
    lines.push('\\sisetup{table-format = 4.0, separate-uncertainty = true}');
    lines.push('\\begin{tabular}{@{}l S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=3.0(2)]@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {Compile} & {WitnessGen} & {Prove} & {Verify} \\\\');
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

// --- Main ---

async function loadPatternDefs(): Promise<PatternDefMap> {
  try {
    const content = await fs.readFile(PATTERNS_FILE, 'utf-8');
    const data = JSON.parse(content);
    const defs: PatternDefMap = {};
    for (const p of data.patterns) {
      defs[p.name] = p;
    }
    return defs;
  } catch {
    console.warn('Warning: Could not load patterns.json');
    return {};
  }
}

async function loadV1Compat(): Promise<V1CompatEntry[]> {
  try {
    const content = await fs.readFile(V1_COMPAT_FILE, 'utf-8');
    const data = JSON.parse(content);
    return data.patterns ?? [];
  } catch {
    console.warn('Warning: Could not load v1-compatibility.json');
    return [];
  }
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

  // Load pattern definitions and v1 compatibility data
  const patternDefs = await loadPatternDefs();
  const v1Compat = await loadV1Compat();

  // Ensure output directory exists
  await fs.mkdir(OUTPUT_DIR, { recursive: true });

  // Generate Markdown
  const markdown = generateMarkdown(results, patternDefs, v1Compat);
  const mdPath = path.join(OUTPUT_DIR, 'results.md');
  await fs.writeFile(mdPath, markdown);
  console.log(`Generated: ${mdPath}`);

  // Generate LaTeX
  const latex = generateLatex(results, patternDefs, v1Compat);
  const texPath = path.join(OUTPUT_DIR, 'tables.tex');
  await fs.writeFile(texPath, latex);
  console.log(`Generated: ${texPath}`);

  console.log('\nDone!');
}

main().catch((error) => {
  console.error('Error generating outputs:', error);
  process.exit(1);
});
