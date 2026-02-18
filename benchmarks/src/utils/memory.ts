/**
 * Memory profiling utilities for benchmarks.
 *
 * Measures actual peak memory (RSS) using /usr/bin/time wrapper.
 * Supports macOS (BSD time) and Linux (GNU time).
 */

import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import type { TimingStats } from '../types.js';
import { calculateStats } from './timing.js';
import { getAbortSignal, isAborted } from './abort.js';

/**
 * Detected platform type for memory profiling.
 */
export type Platform = 'darwin' | 'linux' | 'unsupported';

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
 * Result of a single memory-tracked command execution.
 */
export interface MemoryMeasurement {
  readonly peakRSSMB: number;
  readonly elapsedMs: number;
  readonly exitCode: number;
  readonly stdout: string;
  readonly stderr: string;
}

/**
 * Combined timing and memory statistics from multiple runs.
 */
export interface MeasurementResult {
  readonly timing: TimingStats;
  readonly memory: MemoryStats;
}

/**
 * Options for running a command with memory tracking.
 */
export interface MemoryTrackingOptions {
  readonly cwd?: string;
  readonly runs?: number;
  readonly timeoutMs?: number;
}

/**
 * Detect the current platform for memory profiling.
 */
export function detectPlatform(): Platform {
  const platform = os.platform();
  if (platform === 'darwin') return 'darwin';
  if (platform === 'linux') return 'linux';
  return 'unsupported';
}

/**
 * Get the /usr/bin/time command with appropriate flags for the platform.
 *
 * @param platform - The detected platform
 * @returns The time command prefix, or null if unsupported
 */
export function getTimeCommand(platform: Platform): string | null {
  switch (platform) {
    case 'darwin':
      // macOS BSD time: -l flag outputs resource usage including max RSS in bytes
      return '/usr/bin/time -l';
    case 'linux':
      // GNU time: -v flag outputs verbose resource usage including max RSS in KB
      return '/usr/bin/time -v';
    default:
      return null;
  }
}

/**
 * Parse the output from /usr/bin/time to extract peak RSS.
 *
 * @param stderr - The stderr output from the time command
 * @param platform - The detected platform
 * @returns Peak RSS in megabytes, or 0 if parsing fails
 */
export function parseTimeOutput(stderr: string, platform: Platform): number {
  if (platform === 'darwin') {
    // macOS BSD time output format (bytes):
    // "        12345678  maximum resident set size"
    const match = stderr.match(/(\d+)\s+maximum resident set size/);
    if (match) {
      const bytes = parseInt(match[1], 10);
      return bytes / (1024 * 1024); // bytes -> MB
    }
  } else if (platform === 'linux') {
    // Linux GNU time output format (kilobytes):
    // "Maximum resident set size (kbytes): 12345"
    const match = stderr.match(/Maximum resident set size.*?:\s*(\d+)/);
    if (match) {
      const kb = parseInt(match[1], 10);
      return kb / 1024; // KB -> MB
    }
  }

  return 0;
}

/**
 * Check if /usr/bin/time is available on the system.
 */
export async function isTimeAvailable(): Promise<boolean> {
  const platform = detectPlatform();
  if (platform === 'unsupported') return false;

  try {
    await fs.access('/usr/bin/time', fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

/**
 * Run a single command with memory tracking.
 *
 * @param command - The shell command to execute
 * @param options - Execution options
 * @returns Memory measurement result
 */
async function runSingleWithMemory(
  command: string,
  options: { cwd?: string; timeoutMs?: number }
): Promise<MemoryMeasurement | null> {
  const platform = detectPlatform();
  const timeCmd = getTimeCommand(platform);

  if (!timeCmd) {
    return null;
  }

  // Create a temp file for time's stderr output
  const tempDir = os.tmpdir();
  const timeOutputFile = path.join(tempDir, `time_output_${Date.now()}_${Math.random().toString(36).slice(2)}.txt`);

  try {
    // Wrap command with time, redirecting time's output to a temp file
    // The command's own stderr goes to stderr, time's output goes to file
    const wrappedCommand = `${timeCmd} sh -c '${command.replace(/'/g, "'\\''")}' 2> "${timeOutputFile}"`;

    const start = performance.now();
    const proc = Bun.spawn(['sh', '-c', wrappedCommand], {
      cwd: options.cwd,
      stdout: 'pipe',
      stderr: 'pipe',
      signal: getAbortSignal(),
    });

    const stdout = await new Response(proc.stdout).text();
    const commandStderr = await new Response(proc.stderr).text();
    const exitCode = await proc.exited;
    const end = performance.now();

    // Read time's output from temp file
    let timeStderr = '';
    try {
      timeStderr = await fs.readFile(timeOutputFile, 'utf-8');
    } catch {
      // Time output file might not exist if time itself failed
    }

    // Parse memory from time output
    const peakRSSMB = parseTimeOutput(timeStderr, platform);

    return {
      peakRSSMB,
      elapsedMs: end - start,
      exitCode,
      stdout,
      stderr: commandStderr,
    };
  } catch (e) {
    if (e instanceof Error && e.name === 'AbortError') {
      return null;
    }
    throw e;
  } finally {
    // Clean up temp file
    try {
      await fs.unlink(timeOutputFile);
    } catch {
      // Ignore cleanup errors
    }
  }
}

/**
 * Calculate memory statistics from an array of measurements.
 */
export function calculateMemoryStats(measurements: number[], measured: boolean = true): MemoryStats {
  if (measurements.length === 0) {
    return {
      mean: 0,
      stddev: 0,
      min: 0,
      max: 0,
      runs: 0,
      measured: false,
    };
  }

  const n = measurements.length;
  const mean = measurements.reduce((a, b) => a + b, 0) / n;
  const variance = measurements.reduce((sum, m) => sum + Math.pow(m - mean, 2), 0) / n;
  const stddev = Math.sqrt(variance);
  const min = Math.min(...measurements);
  const max = Math.max(...measurements);

  return {
    mean,
    stddev,
    min,
    max,
    runs: n,
    measured,
  };
}

/**
 * Run a command multiple times with memory and timing tracking.
 *
 * This function replaces the need for separate hyperfine and time-based
 * measurement passes by capturing both timing and memory in a single run.
 *
 * @param command - The shell command to execute
 * @param options - Execution options (cwd, runs, timeout)
 * @returns Combined timing and memory statistics, or null if memory profiling unavailable
 */
export async function runWithMemoryTracking(
  command: string,
  options: MemoryTrackingOptions = {}
): Promise<MeasurementResult | null> {
  const runs = options.runs ?? 3;

  // Check if time is available
  const timeAvailable = await isTimeAvailable();
  if (!timeAvailable) {
    console.log('    Warning: /usr/bin/time not available, memory profiling disabled');
    return null;
  }

  const timings: number[] = [];
  const memories: number[] = [];

  for (let i = 0; i < runs; i++) {
    if (isAborted()) break;
    const result = await runSingleWithMemory(command, {
      cwd: options.cwd,
      timeoutMs: options.timeoutMs,
    });

    if (result) {
      // Only record successful runs (exit code 0)
      if (result.exitCode === 0) {
        timings.push(result.elapsedMs);
        if (result.peakRSSMB > 0) {
          memories.push(result.peakRSSMB);
        }
      } else if (i === 0) {
        // Log first failure for debugging
        console.log(`    Warning: Command failed with exit code ${result.exitCode}`);
      }
    }
  }

  // If no successful runs, return null
  if (timings.length === 0) {
    return null;
  }

  return {
    timing: calculateStats(timings),
    memory: calculateMemoryStats(memories, memories.length > 0),
  };
}

/**
 * Create a default (empty) MemoryStats for cases where measurement is unavailable.
 */
export function defaultMemoryStats(): MemoryStats {
  return {
    mean: 0,
    stddev: 0,
    min: 0,
    max: 0,
    runs: 0,
    measured: false,
  };
}

/**
 * Format memory stats for display.
 */
export function formatMemoryStats(stats: MemoryStats): string {
  if (!stats.measured || stats.runs === 0 || stats.mean === 0) {
    return 'N/A';
  }
  return `${stats.mean.toFixed(0)} ± ${stats.stddev.toFixed(0)} MB (${stats.runs} runs)`;
}
