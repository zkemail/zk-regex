/**
 * Hyperfine wrapper for benchmarking long-running operations.
 *
 * Use for operations over 1 second (proof generation).
 * For fast operations, use in-process timing.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import type { TimingStats, HyperfineOutput } from '../types.js';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import { getAbortSignal } from './abort.js';

/**
 * Options for hyperfine benchmarks.
 */
export interface HyperfineOptions {
  warmup?: number;
  minRuns?: number;
  maxRuns?: number;
  /**
   * Shell to use: 'none' (no shell, -N flag), 'default' (hyperfine default /bin/sh),
   * 'bash' (use bash), or a custom shell path.
   */
  shell?: string;
  cwd?: string;
}

const DEFAULT_OPTIONS: Required<Omit<HyperfineOptions, 'cwd'>> = {
  warmup: 3,
  minRuns: 10,
  maxRuns: 30,
  shell: 'default',
};

/**
 * Check if hyperfine is available.
 */
async function isHyperfineAvailable(): Promise<boolean> {
  try {
    const proc = Bun.spawn(['which', 'hyperfine'], {
      stdout: 'pipe',
      stderr: 'pipe',
    });
    const exitCode = await proc.exited;
    return exitCode === 0;
  } catch {
    return false;
  }
}

/**
 * Wrap a command to source nvm before execution.
 * This ensures snarkjs and other node tools are available.
 */
function wrapCommandWithNvm(command: string): string {
  // Source nvm and then run the command
  return `export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; ${command}`;
}

/**
 * Run a hyperfine benchmark and return timing statistics.
 */
export async function runHyperfine(
  command: string,
  options: HyperfineOptions = {}
): Promise<Result<TimingStats>> {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  // Check if hyperfine is available
  if (!(await isHyperfineAvailable())) {
    return err(errors.hyperfineFailed(command, 'hyperfine not found. Install with: brew install hyperfine'));
  }

  // Create temporary file for JSON output
  const tempFile = path.join(os.tmpdir(), `hyperfine-${Date.now()}.json`);

  try {
    // Build hyperfine command
    const args = [
      'hyperfine',
      `--warmup=${opts.warmup}`,
      `--min-runs=${opts.minRuns}`,
      `--max-runs=${opts.maxRuns}`,
      `--export-json=${tempFile}`,
    ];

    // Handle shell configuration
    let finalCommand = command;
    if (opts.shell === 'none') {
      // No shell - direct execution (can't use shell features like &&)
      args.push('-N');
    } else if (opts.shell === 'default') {
      // Use bash with nvm sourcing for node tools to be available
      args.push('--shell=bash');
      finalCommand = wrapCommandWithNvm(command);
    } else if (opts.shell === 'bash') {
      args.push('--shell=bash');
      finalCommand = wrapCommandWithNvm(command);
    } else {
      // Custom shell path
      args.push(`--shell=${opts.shell}`);
    }

    args.push(finalCommand);

    // Filter out Bun's node shim paths (like /tmp/bun-node-*) that would
    // override nvm's node and cause npm/npx to fail when hyperfine runs
    // shell commands that use snarkjs
    const cleanPath = (process.env.PATH || '')
      .split(':')
      .filter(p => !p.includes('bun-node'))
      .join(':');

    // Run hyperfine
    const proc = Bun.spawn(args, {
      cwd: opts.cwd,
      stdout: 'pipe',
      stderr: 'pipe',
      env: { ...process.env, PATH: cleanPath },
      signal: getAbortSignal(),
    });

    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      const stderr = await new Response(proc.stderr).text();
      return err(errors.hyperfineFailed(command, stderr));
    }

    // Parse JSON output
    const jsonContent = await fs.readFile(tempFile, 'utf-8');
    const output: HyperfineOutput = JSON.parse(jsonContent);

    if (!output.results || output.results.length === 0) {
      return err(errors.invalidOutput('hyperfine', jsonContent));
    }

    const result = output.results[0];

    // Convert seconds to milliseconds
    const stats: TimingStats = {
      mean: result.mean * 1000,
      stddev: result.stddev * 1000,
      min: result.min * 1000,
      max: result.max * 1000,
      runs: result.times.length,
      coefficientOfVariation: result.mean > 0 ? (result.stddev / result.mean) * 100 : 0,
    };

    return ok(stats);
  } catch (error) {
    return err(errors.hyperfineFailed(command, String(error)));
  } finally {
    // Clean up temp file
    try {
      await fs.unlink(tempFile);
    } catch {
      // Ignore cleanup errors
    }
  }
}

/**
 * Run multiple hyperfine benchmarks in sequence.
 */
export async function runHyperfineBatch(
  commands: string[],
  options: HyperfineOptions = {}
): Promise<Map<string, Result<TimingStats>>> {
  const results = new Map<string, Result<TimingStats>>();

  for (const command of commands) {
    results.set(command, await runHyperfine(command, options));
  }

  return results;
}
