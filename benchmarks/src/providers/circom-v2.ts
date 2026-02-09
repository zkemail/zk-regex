/**
 * Circom v2 (NFA-based) benchmark provider.
 *
 * This provider benchmarks the current v2 implementation using
 * the NFA-based compiler with modular helper templates.
 */

import type {
  CircomV2Metrics,
  PatternDefinition,
  BenchmarkConfig,
} from '../types.js';
import type { Result } from '../errors.js';
import { ok } from '../errors.js';
import { BaseBenchmarkProvider, type BenchmarkMetrics } from './base.js';

export class CircomV2Provider extends BaseBenchmarkProvider {
  readonly name = 'circom-v2';

  async setup(): Promise<Result<void>> {
    // TODO: Verify circom is installed and >= 2.1.9
    // TODO: Download/cache Powers of Tau
    return ok(undefined);
  }

  async benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>> {
    // TODO: Implement v2 benchmarking
    // 1. Compile circuit from circom/circuits/common/
    // 2. Extract NFA graph info (states, transitions)
    // 3. Generate witness and measure timing
    // 4. Run snarkjs for constraints and proving
    // 5. Measure with hyperfine

    const metrics: CircomV2Metrics = {
      constraints: 0,
      states: 0,
      transitions: 0,
      witnessGenMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      proveMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      verifyMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      peakMemoryMB: 0,
    };

    return ok(metrics);
  }

  supportsPattern(_pattern: PatternDefinition): boolean {
    // v2 supports all patterns
    return true;
  }
}
