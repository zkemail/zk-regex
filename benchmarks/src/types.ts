/**
 * TypeScript interfaces for ZK-Regex benchmark results.
 *
 * These types define the structure of benchmark data collected from
 * Circom (v1 and v2) and Noir (v2 only) backends.
 */

/**
 * Hardware and environment specification for reproducibility.
 */
export interface HardwareSpec {
  readonly platform: string;
  readonly cpu: string;
  readonly cores: number;
  readonly memoryGB: number;
  readonly os: string;
  readonly timestamp: string;
}

/**
 * Statistical summary of timing measurements.
 */
export interface TimingStats {
  readonly mean: number;
  readonly stddev: number;
  readonly min: number;
  readonly max: number;
  readonly runs: number;
  readonly coefficientOfVariation: number;
}

/**
 * Tool versions for reproducibility.
 */
export interface ToolVersions {
  readonly circom?: string;
  readonly snarkjs?: string;
  readonly nargo?: string;
  readonly barretenberg?: string;
  readonly bun: string;
  readonly node: string;
}

/**
 * Base metrics common to all Circom benchmarks.
 */
export interface CircomMetrics {
  readonly constraints: number;
  readonly witnessGenMs: TimingStats;
  readonly proveMs: TimingStats;
  readonly verifyMs: TimingStats;
  readonly peakMemoryMB: number;
}

/**
 * Extended metrics for v2 Circom, including NFA complexity.
 */
export interface CircomV2Metrics extends CircomMetrics {
  readonly states: number;
  readonly transitions: number;
}

/**
 * Noir backend metrics (v2 only).
 */
export interface NoirMetrics {
  readonly acirOpcodes: number;
  readonly backendGates: number;
  readonly gatesPerByte: number;
  readonly compileMs: TimingStats;
  readonly executeMs: TimingStats;
  readonly proveMs: TimingStats;
  readonly verifyMs: TimingStats;
  readonly proofSizeBytes: number;
}

/**
 * Complete benchmark data for a single pattern at a specific input length.
 */
export interface PatternBenchmark {
  readonly pattern: string;
  readonly inputLengthBytes: number;
  readonly v1Circom?: CircomMetrics;
  readonly v2Circom: CircomV2Metrics;
  readonly v2Noir: NoirMetrics;
}

/**
 * Data point for scaling analysis.
 * Includes data from all three providers where available.
 */
export interface ScalingDataPoint {
  readonly pattern: string;
  readonly inputLengthBytes: number;
  readonly circomV1Constraints?: number;
  readonly circomV2Constraints: number;
  readonly noirGates: number;
  readonly circomV1ProveMs?: number;
  readonly circomV2ProveMs: number;
  readonly noirProveMs: number;
}

/**
 * Complete benchmark results with metadata.
 */
export interface BenchmarkResults {
  readonly version: '1.0.0';
  readonly hardware: HardwareSpec;
  readonly toolVersions: ToolVersions;
  readonly patterns: Record<string, PatternBenchmark>;
  readonly scaling: ScalingDataPoint[];
}

/**
 * Configuration for a single benchmark run.
 */
export interface BenchmarkConfig {
  readonly warmupRuns: number;
  readonly minRuns: number;
  readonly maxRuns: number;
  readonly timeoutMs: number;
  readonly inputLengths: number[];
}

/**
 * Pattern definition for benchmarking.
 */
export interface PatternDefinition {
  readonly name: string;
  readonly description: string;
  readonly circuitName: string;
  readonly availableInV1: boolean;
}

/**
 * Provider type for benchmark execution.
 */
export type ProviderType = 'circom-v1' | 'circom-v2' | 'noir-v2';

/**
 * Powers of Tau file configuration.
 * Note: maxConstraints is auto-calculated from the filename (e.g., pot16 = 2^16).
 */
export interface PtauConfig {
  readonly url: string;
  readonly filename: string;
}

/**
 * Raw hyperfine JSON output structure.
 */
export interface HyperfineResult {
  readonly command: string;
  readonly mean: number;
  readonly stddev: number;
  readonly min: number;
  readonly max: number;
  readonly median: number;
  readonly times: number[];
}

/**
 * Hyperfine benchmark output.
 */
export interface HyperfineOutput {
  readonly results: HyperfineResult[];
}
