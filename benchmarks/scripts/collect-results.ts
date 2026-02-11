#!/usr/bin/env bun
/**
 * Collect and aggregate benchmark results from individual runs.
 *
 * Reads per-pattern results from results/ and produces comparison.json
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import type {
  BenchmarkResults,
  PatternBenchmark,
  CircomMetrics,
  CircomV2Metrics,
  NoirMetrics,
  ScalingDataPoint,
  TimingStats,
} from '../src/types.js';
import { getHardwareSpec, getToolVersions } from '../src/utils/hardware.js';

const RESULTS_DIR = path.join(import.meta.dir, '..', 'results');
const OUTPUT_FILE = path.join(RESULTS_DIR, 'comparison.json');

/**
 * Raw result file structure from providers.
 */
interface RawResultFile {
  provider: 'circom-v1' | 'circom-v2' | 'noir-v2';
  pattern: string;
  inputLengthBytes: number;
  timestamp: string;
  metrics: Record<string, unknown>;
}

/**
 * Parse a result filename into its components.
 * Format: {provider}_{pattern}_{inputLength}.json
 */
function parseFilename(filename: string): { provider: string; pattern: string; inputLength: number } | null {
  const match = filename.match(/^(circom-v1|circom-v2|noir-v2)_(.+)_(\d+)\.json$/);
  if (!match) return null;
  return {
    provider: match[1],
    pattern: match[2],
    inputLength: parseInt(match[3], 10),
  };
}

/**
 * Create a default TimingStats for missing data.
 */
function defaultTimingStats(): TimingStats {
  return {
    mean: 0,
    stddev: 0,
    min: 0,
    max: 0,
    runs: 0,
    coefficientOfVariation: 0,
  };
}

/**
 * Create a default NoirMetrics for missing data.
 */
function defaultNoirMetrics(): NoirMetrics {
  return {
    acirOpcodes: 0,
    backendGates: 0,
    gatesPerByte: 0,
    compileMs: defaultTimingStats(),
    executeMs: defaultTimingStats(),
    proveMs: defaultTimingStats(),
    verifyMs: defaultTimingStats(),
    proofSizeBytes: 0,
  };
}

/**
 * Create a default CircomV2Metrics for missing data.
 */
function defaultCircomV2Metrics(): CircomV2Metrics {
  return {
    constraints: 0,
    states: 0,
    transitions: 0,
    witnessGenMs: defaultTimingStats(),
    proveMs: defaultTimingStats(),
    verifyMs: defaultTimingStats(),
    peakMemoryMB: 0,
  };
}

async function main() {
  console.log('Collecting benchmark results...\n');

  // Find all result files
  let files: string[];
  try {
    files = await fs.readdir(RESULTS_DIR);
  } catch {
    console.error('No results directory found. Run benchmarks first.');
    process.exit(1);
  }

  const jsonFiles = files.filter(f => f.endsWith('.json') && f !== 'comparison.json');

  if (jsonFiles.length === 0) {
    console.log('No benchmark result files found.');
    console.log('Run `bun run bench` to generate results.');
    return;
  }

  console.log(`Found ${jsonFiles.length} result files`);

  // Load and parse all result files
  const rawResults: RawResultFile[] = [];
  for (const filename of jsonFiles) {
    const filePath = path.join(RESULTS_DIR, filename);
    try {
      const content = await fs.readFile(filePath, 'utf-8');
      const data = JSON.parse(content) as RawResultFile;
      rawResults.push(data);
      console.log(`  Loaded: ${filename}`);
    } catch (error) {
      console.warn(`  Warning: Failed to parse ${filename}: ${error}`);
    }
  }

  // Get system info
  console.log('\nCollecting hardware and tool versions...');
  const hardware = getHardwareSpec();
  const toolVersions = await getToolVersions();

  // Group results by pattern and input length
  // Key format: "{pattern}_{inputLength}"
  const grouped = new Map<string, {
    pattern: string;
    inputLength: number;
    circomV1?: RawResultFile;
    circomV2?: RawResultFile;
    noirV2?: RawResultFile;
  }>();

  for (const result of rawResults) {
    const key = `${result.pattern}_${result.inputLengthBytes}`;
    if (!grouped.has(key)) {
      grouped.set(key, {
        pattern: result.pattern,
        inputLength: result.inputLengthBytes,
      });
    }

    const entry = grouped.get(key)!;
    switch (result.provider) {
      case 'circom-v1':
        entry.circomV1 = result;
        break;
      case 'circom-v2':
        entry.circomV2 = result;
        break;
      case 'noir-v2':
        entry.noirV2 = result;
        break;
    }
  }

  // Build PatternBenchmark entries
  // For the patterns record, we use a composite key: "{pattern}@{inputLength}"
  // This allows multiple input lengths per pattern
  const patterns: Record<string, PatternBenchmark> = {};
  const scaling: ScalingDataPoint[] = [];

  for (const [key, entry] of grouped) {
    const patternKey = `${entry.pattern}@${entry.inputLength}`;

    // Parse Circom v1 metrics
    let v1Circom: CircomMetrics | undefined;
    if (entry.circomV1) {
      const m = entry.circomV1.metrics as {
        constraints: number;
        witnessGenMs: TimingStats;
        proveMs: TimingStats;
        verifyMs: TimingStats;
        peakMemoryMB: number;
      };
      v1Circom = {
        constraints: m.constraints,
        witnessGenMs: m.witnessGenMs,
        proveMs: m.proveMs,
        verifyMs: m.verifyMs,
        peakMemoryMB: m.peakMemoryMB,
      };
    }

    // Parse Circom v2 metrics
    let v2Circom: CircomV2Metrics;
    if (entry.circomV2) {
      const m = entry.circomV2.metrics as {
        constraints: number;
        states: number;
        transitions: number;
        witnessGenMs: TimingStats;
        proveMs: TimingStats;
        verifyMs: TimingStats;
        peakMemoryMB: number;
      };
      v2Circom = {
        constraints: m.constraints,
        states: m.states,
        transitions: m.transitions,
        witnessGenMs: m.witnessGenMs,
        proveMs: m.proveMs,
        verifyMs: m.verifyMs,
        peakMemoryMB: m.peakMemoryMB,
      };
    } else {
      v2Circom = defaultCircomV2Metrics();
    }

    // Parse Noir v2 metrics
    let v2Noir: NoirMetrics;
    if (entry.noirV2) {
      const m = entry.noirV2.metrics as {
        acirOpcodes: number;
        backendGates: number;
        gatesPerByte: number;
        compileMs: TimingStats;
        executeMs: TimingStats;
        proveMs: TimingStats;
        verifyMs: TimingStats;
        proofSizeBytes: number;
      };
      v2Noir = {
        acirOpcodes: m.acirOpcodes,
        backendGates: m.backendGates,
        gatesPerByte: m.gatesPerByte,
        compileMs: m.compileMs,
        executeMs: m.executeMs,
        proveMs: m.proveMs,
        verifyMs: m.verifyMs,
        proofSizeBytes: m.proofSizeBytes,
      };
    } else {
      v2Noir = defaultNoirMetrics();
    }

    patterns[patternKey] = {
      pattern: entry.pattern,
      inputLengthBytes: entry.inputLength,
      v1Circom,
      v2Circom,
      v2Noir,
    };

    // Add scaling data point if we have enough data
    if (v2Circom.constraints > 0 || v2Noir.backendGates > 0) {
      scaling.push({
        pattern: entry.pattern,
        inputLengthBytes: entry.inputLength,
        circomConstraints: v2Circom.constraints,
        noirGates: v2Noir.backendGates,
        circomProveMs: v2Circom.proveMs.mean,
        noirProveMs: v2Noir.proveMs.mean,
      });
    }
  }

  // Sort scaling by pattern then input length
  scaling.sort((a, b) => {
    if (a.pattern !== b.pattern) return a.pattern.localeCompare(b.pattern);
    return a.inputLengthBytes - b.inputLengthBytes;
  });

  const results: BenchmarkResults = {
    version: '1.0.0',
    hardware,
    toolVersions,
    patterns,
    scaling,
  };

  // Write output
  await fs.writeFile(OUTPUT_FILE, JSON.stringify(results, null, 2));
  console.log(`\nResults written to: ${OUTPUT_FILE}`);
  console.log(`  - ${Object.keys(patterns).length} pattern benchmarks`);
  console.log(`  - ${scaling.length} scaling data points`);
}

main().catch((error) => {
  console.error('Error collecting results:', error);
  process.exit(1);
});
