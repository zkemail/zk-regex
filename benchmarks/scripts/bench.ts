#!/usr/bin/env bun
/**
 * Main benchmark entry point.
 *
 * Usage:
 *   bun scripts/bench.ts                              # Run all providers, all patterns
 *   bun scripts/bench.ts --provider circom-v2         # Run specific provider
 *   bun scripts/bench.ts --pattern simple_regex       # Run specific pattern
 *   bun scripts/bench.ts --provider circom-v2 --pattern simple_regex  # Both
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import type { ProviderType, PatternDefinition, BenchmarkConfig } from '../src/types.js';
import type { BenchmarkProvider } from '../src/providers/base.js';
import { CircomV1Provider } from '../src/providers/circom-v1.js';
import { CircomV2Provider } from '../src/providers/circom-v2.js';
import { NoirV2Provider } from '../src/providers/noir-v2.js';
import { getHardwareSpec, getToolVersions, verifyDependencies } from '../src/utils/hardware.js';
import { registerCleanupHandler } from '../src/utils/worktree.js';
import { formatError } from '../src/errors.js';

// Parse command line arguments
function parseArgs(): { providers: ProviderType[]; patternFilter: string | null } {
  const args = process.argv.slice(2);

  let providers: ProviderType[] = ['circom-v2', 'noir-v2', 'circom-v1'];
  let patternFilter: string | null = null;

  const providerIndex = args.indexOf('--provider');
  if (providerIndex !== -1 && args[providerIndex + 1]) {
    providers = [args[providerIndex + 1] as ProviderType];
  }

  const patternIndex = args.indexOf('--pattern');
  if (patternIndex !== -1 && args[patternIndex + 1]) {
    patternFilter = args[patternIndex + 1];
  }

  return { providers, patternFilter };
}

// Load patterns from config
async function loadPatterns(): Promise<PatternDefinition[]> {
  const configPath = path.join(import.meta.dir, '..', 'config', 'patterns.json');
  const config = JSON.parse(await fs.readFile(configPath, 'utf-8'));
  return config.patterns;
}

// Load benchmark config
async function loadBenchmarkConfig(): Promise<BenchmarkConfig> {
  const configPath = path.join(import.meta.dir, '..', 'config', 'benchmark.json');
  const config = JSON.parse(await fs.readFile(configPath, 'utf-8'));
  return config.config;
}

// Create provider instance
function createProvider(type: ProviderType): BenchmarkProvider {
  switch (type) {
    case 'circom-v1':
      return new CircomV1Provider();
    case 'circom-v2':
      return new CircomV2Provider();
    case 'noir-v2':
      return new NoirV2Provider();
    default:
      throw new Error(`Unknown provider: ${type}`);
  }
}

// Get required binaries for a provider
function getRequiredBinaries(type: ProviderType): string[] {
  switch (type) {
    case 'circom-v1':
    case 'circom-v2':
      return ['circom', 'hyperfine'];
    case 'noir-v2':
      return ['nargo', 'bb', 'hyperfine'];
  }
}

async function main() {
  console.log('ZK-Regex Benchmark Suite');
  console.log('========================\n');

  // Register cleanup handler for worktrees
  registerCleanupHandler();

  // Parse arguments
  const { providers, patternFilter } = parseArgs();
  console.log(`Providers: ${providers.join(', ')}`);
  if (patternFilter) {
    console.log(`Pattern filter: ${patternFilter}`);
  }
  console.log();

  // Collect hardware info
  console.log('Collecting system information...');
  const hardware = getHardwareSpec();
  const toolVersions = await getToolVersions();
  console.log(`  Platform: ${hardware.platform}`);
  console.log(`  CPU: ${hardware.cpu}`);
  console.log(`  Cores: ${hardware.cores}`);
  console.log(`  Memory: ${hardware.memoryGB}GB`);
  console.log(`  Bun: ${toolVersions.bun}`);
  console.log(`  Circom: ${toolVersions.circom ?? 'not installed'}`);
  console.log(`  Nargo: ${toolVersions.nargo ?? 'not installed'}`);
  console.log();

  // Load configurations
  let patterns = await loadPatterns();
  const config = await loadBenchmarkConfig();

  // Filter patterns if --pattern flag was provided
  if (patternFilter) {
    patterns = patterns.filter(p =>
      p.name.includes(patternFilter) ||
      p.circuitName.includes(patternFilter)
    );
    if (patterns.length === 0) {
      console.error(`No patterns found matching "${patternFilter}"`);
      process.exit(1);
    }
  }

  console.log(`Loaded ${patterns.length} pattern(s) to benchmark`);
  console.log(`Input lengths: ${config.inputLengths.join(', ')} bytes`);
  console.log();

  // Run benchmarks for each provider
  for (const providerType of providers) {
    console.log(`\n--- Provider: ${providerType} ---\n`);

    // Check dependencies
    const binaries = getRequiredBinaries(providerType);
    const depsResult = await verifyDependencies(binaries);
    if (!depsResult.ok) {
      console.error(formatError(depsResult.error));
      continue;
    }

    // Create and set up provider
    const provider = createProvider(providerType);
    const setupResult = await provider.setup();
    if (!setupResult.ok) {
      console.error(`Setup failed: ${formatError(setupResult.error)}`);
      continue;
    }

    try {
      // Benchmark each pattern
      for (const pattern of patterns) {
        if (!provider.supportsPattern(pattern)) {
          console.log(`  Skipping ${pattern.name} (not supported)`);
          continue;
        }

        console.log(`  Benchmarking ${pattern.name}...`);

        for (const inputLength of config.inputLengths) {
          console.log(`    Input length: ${inputLength} bytes`);

          const result = await provider.benchmarkPattern(pattern, inputLength, config);
          if (!result.ok) {
            console.error(`      Error: ${formatError(result.error)}`);
            continue;
          }

          // TODO: Save results to file
          console.log(`      Done (placeholder metrics)`);
        }
      }
    } finally {
      // Always clean up
      await provider.cleanup();
    }
  }

  console.log('\n========================');
  console.log('Benchmarks complete!');
  console.log('Run `bun run collect` to aggregate results.');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
