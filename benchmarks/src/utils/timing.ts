/**
 * In-process timing utilities for fast operations.
 *
 * Use this for operations under 1 second (verification, witness generation).
 * For longer operations, use hyperfine.
 */

import type { TimingStats } from '../types.js';

/**
 * Measure the execution time of a function over multiple runs.
 */
export async function measureAsync<T>(
  fn: () => Promise<T>,
  runs: number,
  warmupRuns: number = 0
): Promise<{ result: T; stats: TimingStats }> {
  // Warmup: execute fn without recording times
  for (let i = 0; i < warmupRuns; i++) {
    await fn();
  }

  const times: number[] = [];
  let result!: T;

  for (let i = 0; i < runs; i++) {
    const start = performance.now();
    result = await fn();
    const end = performance.now();
    times.push(end - start);
  }

  return {
    result,
    stats: calculateStats(times),
  };
}

/**
 * Calculate statistical metrics from an array of timing measurements.
 */
export function calculateStats(times: number[]): TimingStats {
  if (times.length === 0) {
    return {
      mean: 0,
      stddev: 0,
      min: 0,
      max: 0,
      runs: 0,
      coefficientOfVariation: 0,
    };
  }

  const n = times.length;
  const mean = times.reduce((a, b) => a + b, 0) / n;
  const variance = n > 1
    ? times.reduce((sum, t) => sum + Math.pow(t - mean, 2), 0) / (n - 1)
    : 0;
  const stddev = Math.sqrt(variance);
  const min = Math.min(...times);
  const max = Math.max(...times);
  const coefficientOfVariation = mean > 0 ? (stddev / mean) * 100 : 0;

  return {
    mean,
    stddev,
    min,
    max,
    runs: n,
    coefficientOfVariation,
  };
}

/**
 * Check if timing measurements have high variance.
 *
 * Per zk-Bench methodology: CV > 20% indicates high variance.
 */
export function isHighVariance(stats: TimingStats): boolean {
  return stats.coefficientOfVariation > 20;
}

/**
 * Format timing stats for display.
 */
export function formatTimingStats(stats: TimingStats): string {
  return `${stats.mean.toFixed(2)} ± ${stats.stddev.toFixed(2)} ms (${stats.runs} runs, CV: ${stats.coefficientOfVariation.toFixed(1)}%)`;
}
