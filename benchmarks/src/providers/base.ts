/**
 * Base interface for benchmark providers.
 *
 * Each provider (CircomDFA, CircomNFA, NoirNFA) implements this interface
 * to provide a consistent API for benchmarking different backends.
 */

import type {
  CircomMetrics,
  CircomNFAMetrics,
  NoirMetrics,
  PatternDefinition,
  BenchmarkConfig,
  ToolVersions,
} from '../types.js';
import type { Result } from '../errors.js';

/**
 * Generic metrics type for benchmark results.
 */
export type BenchmarkMetrics = CircomMetrics | CircomNFAMetrics | NoirMetrics;

/**
 * Interface for benchmark providers.
 */
export interface BenchmarkProvider {
  /**
   * Provider name for identification.
   */
  readonly name: string;

  /**
   * Get the compiler commit hash used by this provider.
   */
  getCommitHash(): string;

  /**
   * Get the tool versions relevant to this provider.
   */
  getToolVersions(): ToolVersions;

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

