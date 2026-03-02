/**
 * TypeScript interfaces for ZK-Regex benchmark results.
 *
 * These types define the structure of benchmark data collected from
 * Circom (DFA and NFA) and Noir (NFA only) backends.
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
 * Statistical summary of memory measurements.
 * Parallel to TimingStats but for memory (MB).
 */
export interface MemoryStats {
  readonly mean: number; // MB
  readonly stddev: number; // MB
  readonly min: number; // MB
  readonly max: number; // MB
  readonly runs: number;
  readonly measured: boolean; // true = /usr/bin/time, false = estimated/unavailable
}

/**
 * Per-phase memory usage - unified interface for all backends.
 * Uses framework-agnostic names for cross-framework comparison.
 *
 * Phase mapping:
 * - compile: circom CLI / nargo compile
 * - witnessGen: node wasm witness calc / nargo execute (generates witness)
 * - prove: snarkjs groth16 prove / bb prove
 * - verify: snarkjs groth16 verify / bb verify
 */
export interface PhaseMemory {
  readonly compile?: MemoryStats;
  readonly witnessGen?: MemoryStats;
  readonly prove?: MemoryStats;
  readonly verify?: MemoryStats;
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
  readonly memoryByPhase: PhaseMemory;
}

/**
 * Extended metrics for NFA Circom, including NFA complexity.
 */
export interface CircomNFAMetrics extends CircomMetrics {
  readonly states: number;
  readonly transitions: number;
}

/**
 * Noir backend metrics (NFA only).
 */
export interface NoirMetrics {
  readonly acirOpcodes: number;
  readonly backendGates: number;
  readonly gatesPerByte: number;
  readonly compileMs: TimingStats;
  readonly witnessGenMs: TimingStats; // Renamed from executeMs for cross-framework consistency
  readonly proveMs: TimingStats;
  readonly verifyMs: TimingStats;
  readonly proofSizeBytes: number;
  readonly memoryByPhase: PhaseMemory;
}

/**
 * Complete benchmark data for a single pattern at a specific input length.
 */
export interface PatternBenchmark {
  readonly pattern: string;
  readonly inputLengthBytes: number;
  readonly dfaCircom?: CircomMetrics;
  readonly nfaCircom: CircomNFAMetrics;
  readonly nfaNoir: NoirMetrics;
}

/**
 * Data point for scaling analysis.
 * Includes data from all three providers where available.
 */
export interface ScalingDataPoint {
  readonly pattern: string;
  readonly inputLengthBytes: number;
  readonly actualContentLength: number;
  readonly scalingStrategy?: ScalingStrategy;
  readonly circomDfaConstraints?: number;
  readonly circomNfaConstraints: number;
  readonly noirNfaGates: number;
  readonly circomDfaProveMs?: number;
  readonly circomNfaProveMs: number;
  readonly noirNfaProveMs: number;
}

/**
 * Pattern metadata for documentation purposes.
 * Contains regex definition and sample input used for benchmarking.
 */
export interface PatternMetadataEntry {
  readonly regex: string;
  readonly sampleInput: string;
}

/**
 * Result for a single benchmark run, saved as individual JSON file.
 */
export interface BenchmarkResult {
  readonly provider: ProviderType;
  readonly pattern: string;
  readonly inputLengthBytes: number;
  readonly actualContentLength?: number;
  readonly timestamp: string;
  readonly compilerCommitHash: string;
  readonly toolVersions: ToolVersions;
  readonly metrics: CircomMetrics | CircomNFAMetrics | NoirMetrics;
}

/**
 * Complete benchmark results with metadata.
 */
export interface BenchmarkResults {
  readonly version: '1.0.0';
  readonly hardware: HardwareSpec;
  readonly toolVersions: ToolVersions;
  readonly compilerVersions?: Record<ProviderType, string>;
  readonly patterns: Record<string, PatternBenchmark>;
  readonly scaling: ScalingDataPoint[];
  readonly patternMetadata?: Record<string, PatternMetadataEntry>;
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
 * Regex feature classification for academic taxonomy.
 */
export type PatternFeature =
  | 'literals'
  | 'character_classes'
  | 'alternation'
  | 'quantifiers_plus'
  | 'quantifiers_star'
  | 'quantifiers_fixed'
  | 'quantifiers_range'
  | 'quantifiers_lazy'
  | 'quantifiers_unbounded'
  | 'nested_groups'
  | 'capture_groups';

/**
 * Complexity level for dual taxonomy classification.
 */
export type PatternComplexity = 'simple' | 'medium' | 'complex' | 'NFA-only';

/**
 * Pattern category (synthetic benchmark vs real-world usage).
 */
export type PatternCategory = 'synthetic' | 'real-world';

/**
 * Pattern definition for benchmarking.
 */
/**
 * Strategy for scaling input content to fill target length.
 */
export type ScalingStrategy = 'repeat' | 'extend' | 'pad-with-match';

/**
 * Position for character extension in 'extend' strategy.
 */
export type ExtendPosition = 'before-last' | 'end';

/**
 * Pattern definition for benchmarking.
 */
export interface PatternDefinition {
  readonly name: string;
  readonly description: string;
  readonly circuitName: string;
  readonly availableInV1: boolean;
  readonly complexity: PatternComplexity;
  readonly features: PatternFeature[];
  readonly category: PatternCategory;
  readonly regex: string;
  readonly sampleInput: string;
  readonly inputTemplate?: string;
  readonly scalingStrategy?: ScalingStrategy;
  readonly extendChar?: string;
  readonly extendPosition?: ExtendPosition;
}

/**
 * Provider type for benchmark execution.
 */
export type ProviderType = 'circom-dfa' | 'circom-nfa' | 'noir-nfa';

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
