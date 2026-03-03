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
 * 2. Circom DFA vs Circom NFA Comparison (grouped by complexity - PRIMARY)
 * 3. DFA Compiler Compatibility Analysis (failure modes)
 * 4. NFA-Only Patterns (features DFA cannot compile)
 * 5. Scaling Analysis by Complexity
 * 6. Summary Statistics
 * 7. Noir NFA Details (separate section)
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

const COMPLEXITY_ORDER: PatternComplexity[] = ['simple', 'medium', 'complex', 'NFA-only'];

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
function reductionPct(dfa: number, nfa: number): string {
  if (!dfa || !nfa) return '—';
  return `${((1 - nfa / dfa) * 100).toFixed(1)}%`;
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
  const defEntries = [...new Map(Object.values(patternDefs).map(d => [d.name, d])).values()]
    .sort((a, b) => a.name.localeCompare(b.name));
  if (defEntries.length > 0) {
    lines.push('## Pattern Definitions');
    lines.push('');
    lines.push('| Pattern | Complexity | Category | Scaling | Features | Regex | Sample Input |');
    lines.push('|---------|-----------|----------|---------|----------|-------|--------------|');

    for (const def of defEntries) {
      const escapedRegex = escapeForMarkdown(def.regex);
      const escapedInput = escapeForMarkdown(def.sampleInput);
      const features = def.features.join(', ');
      const scaling = def.scalingStrategy ?? '—';
      lines.push(`| ${def.name} | ${def.complexity} | ${def.category} | ${scaling} | ${features} | \`${escapedRegex}\` | \`${escapedInput}\` |`);
    }
    lines.push('');
  }

  // DFA vs NFA Comparison (PRIMARY) - grouped by complexity
  const defaultPatterns = getDefaultInputPatterns(results.patterns);
  const grouped = groupByComplexity(defaultPatterns, patternDefs);

  if (defaultPatterns.length > 0) {
    lines.push('## Circom DFA vs Circom NFA Comparison (64-byte input)');
    lines.push('');

    for (const level of COMPLEXITY_ORDER) {
      const entries = grouped.get(level)!;
      // Only show patterns that have DFA data for comparison sections
      const withDfa = entries.filter(([, data]) => data.dfaCircom != null);
      if (withDfa.length === 0 && level !== 'NFA-only') continue;
      if (level === 'NFA-only') continue; // NFA-only gets its own section

      lines.push(`### ${level.charAt(0).toUpperCase() + level.slice(1)} Patterns`);
      lines.push('');
      lines.push('| Pattern | DFA Constraints | NFA Constraints | Reduction | DFA Prove (ms) | NFA Prove (ms) |');
      lines.push('|---------|-----------------|-----------------|-----------|----------------|----------------|');

      for (const [key, data] of withDfa) {
        const name = getPatternName(key);
        const dfaC = data.dfaCircom!.constraints;
        const nfaC = data.nfaCircom.constraints;
        lines.push(
          `| ${name} | ${dfaC} | ${nfaC} | ${reductionPct(dfaC, nfaC)} | ${formatTimingMarkdown(data.dfaCircom!.proveMs)} | ${formatTimingMarkdown(data.nfaCircom.proveMs)} |`
        );
      }
      lines.push('');
    }
  }

  // DFA Compatibility Analysis
  if (v1Compat.length > 0) {
    lines.push('## DFA Compiler Compatibility Analysis');
    lines.push('');
    lines.push('| Pattern | Complexity | DFA Compiler | Circom Compile | Failure Phase | Error Summary |');
    lines.push('|---------|-----------|--------------|----------------|---------------|---------------|');

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

  // NFA-Only Patterns (those without DFA data)
  const nfaOnlyPatterns = defaultPatterns.filter(([, data]) => data.dfaCircom == null);
  if (nfaOnlyPatterns.length > 0) {
    lines.push('## NFA-Only Patterns');
    lines.push('');
    lines.push('| Pattern | Circom NFA Constraints | Circom NFA Prove (ms) | Noir NFA Gates | Features |');
    lines.push('|---------|------------------------|------------------------|----------------|----------|');

    for (const [key, data] of nfaOnlyPatterns) {
      const name = getPatternName(key);
      const def = patternDefs[name];
      const features = def?.features.join(', ') ?? '';
      lines.push(
        `| ${name} | ${data.nfaCircom.constraints} | ${formatTimingMarkdown(data.nfaCircom.proveMs)} | ${data.nfaNoir.backendGates || '—'} | ${features} |`
      );
    }
    lines.push('');
  }

  // Scaling Analysis by Complexity
  if (results.scaling.length > 0) {
    lines.push('## Scaling Methodology');
    lines.push('');
    lines.push('For each input length, the actual input fed to the circuit is filled with');
    lines.push('**regex-matching content** (not zero-padded short samples). This ensures');
    lines.push('benchmarks measure the cost of real regex work at each size, not just');
    lines.push('circuit overhead for unused capacity.');
    lines.push('');
    lines.push('Three content-scaling strategies are used per pattern:');
    lines.push('');
    lines.push('- **repeat**: Template string is tiled to fill the target length (e.g., `"hello "` repeated)');
    lines.push('- **extend**: A variable-length match portion grows (e.g., `a*b` becomes `aaa...ab`)');
    lines.push('- **pad-with-match**: Anchored template is placed at start, rest filled with safe filler');
    lines.push('');

    lines.push('### Input Scaling per Pattern');
    lines.push('');
    lines.push('| Pattern | Strategy | Template | Content at 64B | Content at 512B |');
    lines.push('|---------|----------|----------|----------------|-----------------|');

    // Show unique patterns with their scaling strategy
    const seenPatterns = new Set<string>();
    for (const point of results.scaling) {
      if (seenPatterns.has(point.pattern)) continue;
      seenPatterns.add(point.pattern);

      const def = patternDefs[point.pattern];
      const strategy = point.scalingStrategy ?? def?.scalingStrategy ?? '—';
      const template = def?.inputTemplate
        ? '`' + escapeForMarkdown(def.inputTemplate.length > 25 ? def.inputTemplate.slice(0, 22) + '...' : def.inputTemplate) + '`'
        : '—';

      // Find data points for this pattern at 64 and 512
      const at64 = results.scaling.find(p => p.pattern === point.pattern && p.inputLengthBytes === 64);
      const at512 = results.scaling.find(p => p.pattern === point.pattern && p.inputLengthBytes === 512);
      const content64 = at64 ? `${at64.actualContentLength}B` : '—';
      const content512 = at512 ? `${at512.actualContentLength}B` : '—';

      lines.push(`| ${point.pattern} | ${strategy} | ${template} | ${content64} | ${content512} |`);
    }
    lines.push('');

    lines.push('## Scaling: Circuit Size by Input Length');
    lines.push('');
    lines.push('| Pattern | Complexity | Input (bytes) | Content (bytes) | Circom DFA R1CS | Circom NFA R1CS | Noir NFA Gates |');
    lines.push('|---------|-----------|---------------|-----------------|-----------------|-----------------|----------------|');

    for (const point of results.scaling) {
      const def = patternDefs[point.pattern];
      const complexity = def?.complexity ?? '?';
      const dfaR1CS = point.circomDfaConstraints ?? '—';
      const nfaR1CS = point.circomNfaConstraints || '—';
      const nfaGates = point.noirNfaGates || '—';
      lines.push(
        `| ${point.pattern} | ${complexity} | ${point.inputLengthBytes} | ${point.actualContentLength} | ${dfaR1CS} | ${nfaR1CS} | ${nfaGates} |`
      );
    }
    lines.push('');

    lines.push('## Scaling: Proving Time by Input Length');
    lines.push('');
    lines.push('| Pattern | Complexity | Input (bytes) | Content (bytes) | Circom DFA (ms) | Circom NFA (ms) | Noir NFA (ms) |');
    lines.push('|---------|-----------|---------------|-----------------|-----------------|-----------------|---------------|');

    for (const point of results.scaling) {
      const def = patternDefs[point.pattern];
      const complexity = def?.complexity ?? '?';
      const dfaProve = point.circomDfaProveMs && point.circomDfaProveMs > 0 ? point.circomDfaProveMs.toFixed(0) : '—';
      const nfaProve = point.circomNfaProveMs > 0 ? point.circomNfaProveMs.toFixed(0) : '—';
      const noirProve = point.noirNfaProveMs > 0 ? point.noirNfaProveMs.toFixed(0) : '—';
      lines.push(
        `| ${point.pattern} | ${complexity} | ${point.inputLengthBytes} | ${point.actualContentLength} | ${dfaProve} | ${nfaProve} | ${noirProve} |`
      );
    }
    lines.push('');
  }

  // Summary Statistics
  if (defaultPatterns.length > 0) {
    lines.push('## Summary Statistics');
    lines.push('');
    lines.push('| Complexity | Patterns | Avg DFA Constraints | Avg NFA Constraints | Avg Reduction | Notes |');
    lines.push('|-----------|----------|---------------------|---------------------|---------------|-------|');

    for (const level of COMPLEXITY_ORDER) {
      const entries = grouped.get(level)!;
      if (entries.length === 0) continue;
      const withDfa = entries.filter(([, d]) => d.dfaCircom != null);
      const avgDfa = withDfa.length > 0
        ? Math.round(withDfa.reduce((s, [, d]) => s + d.dfaCircom!.constraints, 0) / withDfa.length)
        : '—';
      const avgNfa = Math.round(entries.reduce((s, [, d]) => s + d.nfaCircom.constraints, 0) / entries.length);
      const avgReduction = withDfa.length > 0
        ? ((1 - entries.reduce((s, [, d]) => s + d.nfaCircom.constraints, 0) / withDfa.reduce((s, [, d]) => s + d.dfaCircom!.constraints, 0)) * 100).toFixed(1) + '%'
        : '—';
      const nfaOnly = entries.length - withDfa.length;
      const notes = nfaOnly > 0 ? `${nfaOnly} NFA-only` : `${withDfa.length} compared`;
      lines.push(`| ${level} | ${entries.length} | ${avgDfa} | ${avgNfa} | ${avgReduction} | ${notes} |`);
    }
    lines.push('');
  }

  // Noir NFA Details (separate section)
  const patternsWithNoir = defaultPatterns.filter(([, data]) => data.nfaNoir.backendGates > 0);
  if (patternsWithNoir.length > 0) {
    lines.push('## Noir NFA (UltraHonk) Backend Details (64-byte input)');
    lines.push('');
    lines.push('| Pattern | Complexity | ACIR Opcodes | Backend Gates | Gates/Byte | Prove (ms) | Verify (ms) | Proof Size |');
    lines.push('|---------|-----------|--------------|---------------|------------|------------|-------------|------------|');

    for (const [key, data] of patternsWithNoir) {
      const name = getPatternName(key);
      const def = patternDefs[name];
      const complexity = def?.complexity ?? '?';
      const noir = data.nfaNoir;
      lines.push(
        `| ${name} | ${complexity} | ${noir.acirOpcodes} | ${noir.backendGates} | ${noir.gatesPerByte.toFixed(1)} | ${formatTimingMarkdown(noir.proveMs)} | ${formatTimingMarkdown(noir.verifyMs)} | ${formatBytes(noir.proofSizeBytes)} |`
      );
    }
    lines.push('');
  }

  // Memory Usage - Circom DFA
  if (defaultPatterns.length > 0) {
    const patternsWithMemory = defaultPatterns.filter(([, data]) => {
      const mem = data.dfaCircom?.memoryByPhase;
      return mem?.compile?.measured || mem?.witnessGen?.measured ||
             mem?.prove?.measured || mem?.verify?.measured;
    });
    if (patternsWithMemory.length > 0) {
      lines.push('## Memory Usage by Phase (MB) - Circom DFA');
      lines.push('');
      lines.push('| Pattern | Compile | WitnessGen | Prove | Verify |');
      lines.push('|---------|---------|------------|-------|--------|');

      for (const [key, data] of patternsWithMemory) {
        const name = getPatternName(key);
        const mem = data.dfaCircom!.memoryByPhase;
        lines.push(
          `| ${name} | ${formatMemoryMarkdown(mem?.compile)} | ${formatMemoryMarkdown(mem?.witnessGen)} | ${formatMemoryMarkdown(mem?.prove)} | ${formatMemoryMarkdown(mem?.verify)} |`
        );
      }
      lines.push('');
    }
  }

  // Memory Usage - Circom NFA
  if (defaultPatterns.length > 0) {
    const patternsWithMemory = defaultPatterns.filter(([, data]) => {
      const mem = data.nfaCircom.memoryByPhase;
      return mem?.compile?.measured || mem?.witnessGen?.measured ||
             mem?.prove?.measured || mem?.verify?.measured;
    });
    if (patternsWithMemory.length > 0) {
      lines.push('## Memory Usage by Phase (MB) - Circom NFA');
      lines.push('');
      lines.push('| Pattern | Compile | WitnessGen | Prove | Verify |');
      lines.push('|---------|---------|------------|-------|--------|');

      for (const [key, data] of patternsWithMemory) {
        const name = getPatternName(key);
        const mem = data.nfaCircom.memoryByPhase;
        lines.push(
          `| ${name} | ${formatMemoryMarkdown(mem?.compile)} | ${formatMemoryMarkdown(mem?.witnessGen)} | ${formatMemoryMarkdown(mem?.prove)} | ${formatMemoryMarkdown(mem?.verify)} |`
        );
      }
      lines.push('');
    }
  }

  // Memory Usage - Noir NFA
  if (defaultPatterns.length > 0) {
    const patternsWithMemory = defaultPatterns.filter(([, data]) => {
      const mem = data.nfaNoir.memoryByPhase;
      return mem?.compile?.measured || mem?.witnessGen?.measured ||
             mem?.prove?.measured || mem?.verify?.measured;
    });
    if (patternsWithMemory.length > 0) {
      lines.push('## Memory Usage by Phase (MB) - Noir NFA');
      lines.push('');
      lines.push('| Pattern | Compile | WitnessGen | Prove | Verify |');
      lines.push('|---------|---------|------------|-------|--------|');

      for (const [key, data] of patternsWithMemory) {
        const name = getPatternName(key);
        const mem = data.nfaNoir.memoryByPhase;
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

  const defEntries = [...new Map(Object.values(patternDefs).map(d => [d.name, d])).values()]
    .sort((a, b) => a.name.localeCompare(b.name));
  const defaultPatterns = getDefaultInputPatterns(results.patterns);
  const grouped = groupByComplexity(defaultPatterns, patternDefs);

  // Table 0: Pattern Definitions with complexity
  if (defEntries.length > 0) {
    lines.push('% Table 0: Pattern Definitions');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Pattern Definitions with Complexity Classification and Input Scaling Strategy}');
    lines.push('\\label{tab:patterns}');
    lines.push('\\begin{tabular}{@{}lllllp{0.2\\textwidth}@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & Complexity & Category & Scaling & Features & Regex \\\\');
    lines.push('\\midrule');

    for (const def of defEntries) {
      const escapedRegex = escapeLatexVerbatim(def.regex);
      const features = def.features.slice(0, 2).join(', ').replace(/_/g, '\\_');
      const scaling = def.scalingStrategy ?? '---';
      lines.push(`${escapeLatex(def.name)} & ${def.complexity} & ${def.category} & ${scaling} & ${features} & \\texttt{${escapedRegex}} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 1: DFA vs NFA Comparison (PRIMARY) - grouped by complexity
  if (defaultPatterns.length > 0) {
    lines.push('% Table 1: Circom DFA vs Circom NFA Circuit Size Comparison (grouped by complexity)');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Circom DFA vs Circom NFA Circuit Size Comparison at 64-byte input}');
    lines.push('\\label{tab:dfa-nfa-comparison}');
    lines.push('\\sisetup{');
    lines.push('  table-format = 6.0,');
    lines.push('  round-mode = places,');
    lines.push('  round-precision = 0,');
    lines.push('}');
    lines.push('\\begin{tabular}{@{}ll S S S[table-format=2.1] S[table-format=4.0(2)] S[table-format=4.0(2)]@{}}');
    lines.push('\\toprule');
    lines.push('Complexity & Pattern & {DFA R1CS} & {NFA R1CS} & {Reduction (\\%)} & {DFA Prove (ms)} & {NFA Prove (ms)} \\\\');
    lines.push('\\midrule');

    for (const level of COMPLEXITY_ORDER) {
      if (level === 'NFA-only') continue;
      const entries = grouped.get(level)!.filter(([, d]) => d.dfaCircom != null);
      if (entries.length === 0) continue;

      for (let i = 0; i < entries.length; i++) {
        const [key, data] = entries[i];
        const name = getPatternName(key);
        const levelCol = i === 0 ? level : '';
        const dfaC = data.dfaCircom!.constraints;
        const nfaC = data.nfaCircom.constraints;
        const red = dfaC > 0 ? ((1 - nfaC / dfaC) * 100).toFixed(1) : '{---}';
        lines.push(`${levelCol} & ${escapeLatex(name)} & ${dfaC} & ${nfaC} & ${red} & ${formatTimingLatex(data.dfaCircom!.proveMs)} & ${formatTimingLatex(data.nfaCircom.proveMs)} \\\\`);
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

  // Table 2: DFA Compatibility Analysis
  if (v1Compat.length > 0) {
    lines.push('% Table 2: DFA Compiler Compatibility Analysis');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{DFA Compiler Compatibility Analysis}');
    lines.push('\\label{tab:dfa-compat}');
    lines.push('\\begin{tabular}{@{}llllp{0.3\\textwidth}@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & Complexity & DFA Compiler & Circom & Notes \\\\');
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

  // Table 3: NFA-Only patterns
  const nfaOnlyPatterns = defaultPatterns.filter(([, d]) => d.dfaCircom == null);
  if (nfaOnlyPatterns.length > 0) {
    lines.push('% Table 3: NFA-Only Patterns');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{NFA-Only Patterns (DFA cannot compile)}');
    lines.push('\\label{tab:nfa-only}');
    lines.push('\\sisetup{table-format = 5.0, separate-uncertainty = true}');
    lines.push('\\begin{tabular}{@{}l S S[table-format=4.0(2)] S@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {Circom NFA R1CS} & {Circom NFA Prove (ms)} & {Noir NFA Gates} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of nfaOnlyPatterns) {
      const name = getPatternName(key);
      lines.push(`${escapeLatex(name)} & ${data.nfaCircom.constraints} & ${formatTimingLatex(data.nfaCircom.proveMs)} & ${data.nfaNoir.backendGates || '{---}'} \\\\`);
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
    lines.push('% Note: "Content (B)" shows actual regex-matching bytes fed to the circuit.');
    lines.push('% Unlike zero-padded benchmarks, content fills the full input capacity.');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Circuit Size Scaling by Input Length. Content column shows');
    lines.push('bytes of regex-matching text (not zero-padded).}');
    lines.push('\\label{tab:scaling-size}');
    lines.push('\\sisetup{table-format = 6.0}');
    lines.push('\\begin{tabular}{@{}ll S[table-format=3.0] S[table-format=3.0] S S S@{}}');
    lines.push('\\toprule');
    lines.push('Complexity & Pattern & {Capacity (B)} & {Content (B)} & {DFA R1CS} & {Circom NFA R1CS} & {Noir NFA Gates} \\\\');
    lines.push('\\midrule');

    for (const [pattern, points] of patternGroups) {
      const def = patternDefs[pattern];
      const complexity = def?.complexity ?? '?';
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        const complexCol = i === 0 ? complexity : '';
        const patternCol = i === 0 ? escapeLatex(pattern) : '';
        lines.push(`${complexCol} & ${patternCol} & ${point.inputLengthBytes} & ${point.actualContentLength} & ${point.circomDfaConstraints ?? '{---}'} & ${point.circomNfaConstraints || '{---}'} & ${point.noirNfaGates || '{---}'} \\\\`);
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
    lines.push('\\caption{Proving Time Scaling by Input Length. Content column shows');
    lines.push('bytes of regex-matching text (not zero-padded).}');
    lines.push('\\label{tab:scaling-time}');
    lines.push('\\sisetup{table-format = 4.0}');
    lines.push('\\begin{tabular}{@{}ll S[table-format=3.0] S[table-format=3.0] S S S@{}}');
    lines.push('\\toprule');
    lines.push('Complexity & Pattern & {Capacity (B)} & {Content (B)} & {DFA (ms)} & {Circom NFA (ms)} & {Noir NFA (ms)} \\\\');
    lines.push('\\midrule');

    for (const [pattern, points] of patternGroups) {
      const def = patternDefs[pattern];
      const complexity = def?.complexity ?? '?';
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        const complexCol = i === 0 ? complexity : '';
        const patternCol = i === 0 ? escapeLatex(pattern) : '';
        const dfaProve = point.circomDfaProveMs && point.circomDfaProveMs > 0 ? point.circomDfaProveMs.toFixed(0) : '{---}';
        const nfaProve = point.circomNfaProveMs > 0 ? point.circomNfaProveMs.toFixed(0) : '{---}';
        const noirProve = point.noirNfaProveMs > 0 ? point.noirNfaProveMs.toFixed(0) : '{---}';
        lines.push(`${complexCol} & ${patternCol} & ${point.inputLengthBytes} & ${point.actualContentLength} & ${dfaProve} & ${nfaProve} & ${noirProve} \\\\`);
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
    lines.push('Complexity & {Patterns} & {Avg DFA R1CS} & {Avg Circom NFA R1CS} & {Avg Reduction (\\%)} \\\\');
    lines.push('\\midrule');

    for (const level of COMPLEXITY_ORDER) {
      const entries = grouped.get(level)!;
      if (entries.length === 0) continue;
      const withDfa = entries.filter(([, d]) => d.dfaCircom != null);
      const avgDfa = withDfa.length > 0
        ? Math.round(withDfa.reduce((s, [, d]) => s + d.dfaCircom!.constraints, 0) / withDfa.length)
        : '{---}';
      const avgNfa = Math.round(entries.reduce((s, [, d]) => s + d.nfaCircom.constraints, 0) / entries.length);
      const avgReduction = withDfa.length > 0 && typeof avgDfa === 'number'
        ? ((1 - avgNfa / avgDfa) * 100).toFixed(1)
        : '{---}';
      lines.push(`${level} & ${entries.length} & ${avgDfa} & ${avgNfa} & ${avgReduction} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 6: Noir NFA Details (separate section)
  const patternsWithNoir = defaultPatterns.filter(([, data]) => data.nfaNoir.backendGates > 0);
  if (patternsWithNoir.length > 0) {
    lines.push('% Table 6: Noir NFA Backend Details');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Noir NFA (UltraHonk) Backend Details at 64-byte input}');
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
      const noir = data.nfaNoir;
      lines.push(`${complexity} & ${escapeLatex(name)} & ${noir.acirOpcodes} & ${noir.backendGates} & ${noir.gatesPerByte.toFixed(1)} & ${formatTimingLatex(noir.proveMs)} & ${formatTimingLatex(noir.verifyMs)} & ${noir.proofSizeBytes} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 7: Memory Usage - Circom DFA
  const patternsWithCircomDfaMemory = defaultPatterns.filter(([, data]) => {
    const mem = data.dfaCircom?.memoryByPhase;
    return mem?.compile?.measured || mem?.witnessGen?.measured ||
           mem?.prove?.measured || mem?.verify?.measured;
  });
  if (patternsWithCircomDfaMemory.length > 0) {
    lines.push('% Table 7: Memory Usage - Circom DFA');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Memory Usage by Phase (MB) - Circom DFA at 64-byte input}');
    lines.push('\\label{tab:memory-circom-dfa}');
    lines.push('\\sisetup{table-format = 4.0, separate-uncertainty = true}');
    lines.push('\\begin{tabular}{@{}l S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=3.0(2)]@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {Compile} & {WitnessGen} & {Prove} & {Verify} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of patternsWithCircomDfaMemory) {
      const name = getPatternName(key);
      const mem = data.dfaCircom!.memoryByPhase;
      lines.push(`${escapeLatex(name)} & ${formatMemoryLatex(mem?.compile)} & ${formatMemoryLatex(mem?.witnessGen)} & ${formatMemoryLatex(mem?.prove)} & ${formatMemoryLatex(mem?.verify)} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
    lines.push('');
  }

  // Table 8: Memory Usage - Circom NFA
  const patternsWithCircomMemory = defaultPatterns.filter(([, data]) => {
    const mem = data.nfaCircom.memoryByPhase;
    return mem?.compile?.measured || mem?.witnessGen?.measured ||
           mem?.prove?.measured || mem?.verify?.measured;
  });
  if (patternsWithCircomMemory.length > 0) {
    lines.push('% Table 8: Memory Usage - Circom NFA');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Memory Usage by Phase (MB) - Circom NFA at 64-byte input}');
    lines.push('\\label{tab:memory-circom-nfa}');
    lines.push('\\sisetup{table-format = 4.0, separate-uncertainty = true}');
    lines.push('\\begin{tabular}{@{}l S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=3.0(2)]@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {Compile} & {WitnessGen} & {Prove} & {Verify} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of patternsWithCircomMemory) {
      const name = getPatternName(key);
      const mem = data.nfaCircom.memoryByPhase;
      lines.push(`${escapeLatex(name)} & ${formatMemoryLatex(mem?.compile)} & ${formatMemoryLatex(mem?.witnessGen)} & ${formatMemoryLatex(mem?.prove)} & ${formatMemoryLatex(mem?.verify)} \\\\`);
    }

    lines.push('\\bottomrule');
    lines.push('\\end{tabular}');
    lines.push('\\end{table}');
  }

  // Table 9: Memory Usage - Noir NFA
  const patternsWithNoirMemory = defaultPatterns.filter(([, data]) => {
    const mem = data.nfaNoir.memoryByPhase;
    return mem?.compile?.measured || mem?.witnessGen?.measured ||
           mem?.prove?.measured || mem?.verify?.measured;
  });
  if (patternsWithNoirMemory.length > 0) {
    lines.push('');
    lines.push('% Table 9: Memory Usage - Noir NFA');
    lines.push('\\begin{table}[htbp]');
    lines.push('\\centering');
    lines.push('\\caption{Memory Usage by Phase (MB) - Noir NFA at 64-byte input}');
    lines.push('\\label{tab:memory-noir-nfa}');
    lines.push('\\sisetup{table-format = 4.0, separate-uncertainty = true}');
    lines.push('\\begin{tabular}{@{}l S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=4.0(2)] S[table-format=3.0(2)]@{}}');
    lines.push('\\toprule');
    lines.push('Pattern & {Compile} & {WitnessGen} & {Prove} & {Verify} \\\\');
    lines.push('\\midrule');

    for (const [key, data] of patternsWithNoirMemory) {
      const name = getPatternName(key);
      const mem = data.nfaNoir.memoryByPhase;
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
      // Key by both name and circuitName since result files use circuitName
      defs[p.name] = p;
      defs[p.circuitName] = p;
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

  // Load pattern definitions and DFA compatibility data
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
