#!/usr/bin/env bun
/**
 * Main benchmark entry point.
 *
 * Usage:
 *   bun scripts/bench.ts                    # Run all providers
 *   bun scripts/bench.ts --provider circom-v1
 *   bun scripts/bench.ts --provider circom-v2
 *   bun scripts/bench.ts --provider noir-v2
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
function parseArgs(): { providers: ProviderType[] } {
  const args = process.argv.slice(2);
  const providerIndex = args.indexOf('--provider');

  if (providerIndex !== -1 && args[providerIndex + 1]) {
    const provider = args[providerIndex + 1] as ProviderType;
    return { providers: [provider] };
  }

  // Default: run all providers
  return { providers: ['circom-v2', 'noir-v2', 'circom-v1'] };
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
  const { providers } = parseArgs();
  console.log(`Providers: ${providers.join(', ')}\n`);

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
  const patterns = await loadPatterns();
  const config = await loadBenchmarkConfig();
  console.log(`Loaded ${patterns.length} patterns to benchmark`);
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
