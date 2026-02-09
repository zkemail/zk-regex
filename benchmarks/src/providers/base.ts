/**
 * Base interface for benchmark providers.
 *
 * Each provider (CircomV1, CircomV2, NoirV2) implements this interface
 * to provide a consistent API for benchmarking different backends.
 */

import type {
  CircomMetrics,
  CircomV2Metrics,
  NoirMetrics,
  PatternDefinition,
  BenchmarkConfig,
} from '../types.js';
import type { Result } from '../errors.js';

/**
 * Generic metrics type for benchmark results.
 */
export type BenchmarkMetrics = CircomMetrics | CircomV2Metrics | NoirMetrics;

/**
 * Interface for benchmark providers.
 */
export interface BenchmarkProvider {
  /**
   * Provider name for identification.
   */
  readonly name: string;

  /**
   * Initialize the provider (e.g., set up worktree, check dependencies).
   */
  setup(): Promise<Result<void>>;

  /**
   * Benchmark a single pattern at a specific input length.
   */
  benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>>;

  /**
   * Check if this provider supports a given pattern.
   */
  supportsPattern(pattern: PatternDefinition): boolean;

  /**
   * Clean up resources (e.g., remove worktree).
   */
  cleanup(): Promise<void>;
}

/**
 * Abstract base class with common functionality.
 */
export abstract class BaseBenchmarkProvider implements BenchmarkProvider {
  abstract readonly name: string;

  abstract setup(): Promise<Result<void>>;

  abstract benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>>;

  abstract supportsPattern(pattern: PatternDefinition): boolean;

  async cleanup(): Promise<void> {
    // Default: no cleanup needed
  }
}
