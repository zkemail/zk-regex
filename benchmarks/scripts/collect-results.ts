#!/usr/bin/env bun
/**
 * Collect and aggregate benchmark results from individual runs.
 *
 * Reads per-pattern results from results/ and produces comparison.json
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import type { BenchmarkResults } from '../src/types.js';

const RESULTS_DIR = path.join(import.meta.dir, '..', 'results');
const OUTPUT_FILE = path.join(RESULTS_DIR, 'comparison.json');

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

  // TODO: Implement result aggregation
  // 1. Load all result files
  // 2. Merge by pattern and input length
  // 3. Calculate comparison metrics
  // 4. Write comparison.json

  const results: BenchmarkResults = {
    version: '1.0.0',
    hardware: {
      platform: '',
      cpu: '',
      cores: 0,
      memoryGB: 0,
      os: '',
      timestamp: new Date().toISOString(),
    },
    toolVersions: {
      bun: Bun.version,
      node: process.version,
    },
    patterns: {},
    scaling: [],
  };

  // Write output
  await fs.writeFile(OUTPUT_FILE, JSON.stringify(results, null, 2));
  console.log(`\nResults written to: ${OUTPUT_FILE}`);
}

main().catch((error) => {
  console.error('Error collecting results:', error);
  process.exit(1);
});
