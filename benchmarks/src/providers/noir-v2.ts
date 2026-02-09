/**
 * Noir v2 (NFA-based) benchmark provider.
 *
 * This provider benchmarks the Noir backend, which uses sparse array
 * encoding for O(1) transition lookup (~14.5 gates per lookup).
 */

import type {
  NoirMetrics,
  PatternDefinition,
  BenchmarkConfig,
} from '../types.js';
import type { Result } from '../errors.js';
import { ok } from '../errors.js';
import { BaseBenchmarkProvider, type BenchmarkMetrics } from './base.js';

export class NoirV2Provider extends BaseBenchmarkProvider {
  readonly name = 'noir-v2';

  async setup(): Promise<Result<void>> {
    // TODO: Verify nargo is installed
    // TODO: Verify barretenberg (bb) is installed
    return ok(undefined);
  }

  async benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>> {
    // TODO: Implement Noir benchmarking
    // 1. Create temporary benchmark harness (Noir circuits are libraries)
    // 2. Clean target/ for accurate compile timing
    // 3. Compile with nargo compile
    // 4. Parse nargo info text output (no --json flag!)
    // 5. Execute with nargo execute
    // 6. Prove with bb prove_ultra_honk
    // 7. Verify with bb verify_ultra_honk
    // 8. Get proof size

    const metrics: NoirMetrics = {
      acirOpcodes: 0,
      backendGates: 0,
      gatesPerByte: 0,
      compileMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      executeMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      proveMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      verifyMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      proofSizeBytes: 0,
    };

    return ok(metrics);
  }

  supportsPattern(_pattern: PatternDefinition): boolean {
    // v2 Noir supports all patterns
    return true;
  }
}
