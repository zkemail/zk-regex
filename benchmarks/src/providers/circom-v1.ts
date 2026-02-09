/**
 * Circom v1 (DFA-based) benchmark provider.
 *
 * This provider creates a git worktree of the main branch to benchmark
 * the v1 DFA-based compiler against the current v2 implementation.
 */

import type {
  CircomMetrics,
  PatternDefinition,
  BenchmarkConfig,
} from '../types.js';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import { BaseBenchmarkProvider, type BenchmarkMetrics } from './base.js';

export class CircomV1Provider extends BaseBenchmarkProvider {
  readonly name = 'circom-v1';
  private worktreePath: string | null = null;

  async setup(): Promise<Result<void>> {
    // TODO: Implement v1 worktree setup
    // 1. Create worktree from main branch
    // 2. Install dependencies with yarn
    // 3. Build compiler
    return ok(undefined);
  }

  async benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>> {
    if (!this.supportsPattern(pattern)) {
      return err(errors.compilationFailed(pattern.name, 'Pattern not available in v1'));
    }

    // TODO: Implement v1 benchmarking
    // 1. Compile circuit from packages/circom/circuits/common/
    // 2. Generate witness
    // 3. Run snarkjs for constraints and proving
    // 4. Measure timing with hyperfine

    const metrics: CircomMetrics = {
      constraints: 0,
      witnessGenMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      proveMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      verifyMs: { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 },
      peakMemoryMB: 0,
    };

    return ok(metrics);
  }

  supportsPattern(pattern: PatternDefinition): boolean {
    return pattern.availableInV1;
  }

  async cleanup(): Promise<void> {
    // TODO: Remove worktree and prune
    if (this.worktreePath) {
      // await execAsync(`git worktree remove --force ${this.worktreePath}`);
      // await execAsync('git worktree prune');
      this.worktreePath = null;
    }
  }
}
