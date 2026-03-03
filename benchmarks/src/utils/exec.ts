/**
 * Shared shell execution utilities.
 *
 * Consolidates all shell execution variants (providers, worktree, snarkjs,
 * hardware) into a single configurable function.
 */

import type { BenchmarkError, Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import { getAbortSignal } from './abort.js';

export interface ExecOptions {
  cwd?: string;
  timeout?: number;
  /** Spawn bash with NVM sourcing and filter bun-node from PATH. Default: false */
  useNvm?: boolean;
  /** Error factory for failures. Default: errors.compilationFailed */
  errorFactory?: (command: string, stderr: string) => BenchmarkError;
}

/**
 * Execute a shell command and return result.
 *
 * Behavioral modes via options:
 * - useNvm: false (default) → sh shell, no PATH changes
 * - useNvm: true → bash shell, NVM sourcing, bun-node PATH filtering
 * - errorFactory → configurable error type per call site
 */
export async function execAsync(
  command: string,
  options: ExecOptions = {}
): Promise<Result<string>> {
  const { cwd, useNvm = false, errorFactory = errors.compilationFailed } = options;

  try {
    let shell: string[];
    let env: Record<string, string | undefined> | undefined;

    if (useNvm) {
      const nvmCommand = `
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        ${command}
      `;
      const cleanPath = (process.env.PATH || '')
        .split(':')
        .filter(p => !p.includes('bun-node'))
        .join(':');
      shell = ['bash', '-c', nvmCommand];
      env = { ...process.env, PATH: cleanPath };
    } else {
      shell = ['sh', '-c', command];
    }

    const proc = Bun.spawn(shell, {
      cwd,
      stdout: 'pipe',
      stderr: 'pipe',
      env,
      signal: getAbortSignal(),
    });

    const stdout = await new Response(proc.stdout).text();
    const stderr = await new Response(proc.stderr).text();
    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      return err(errorFactory(command, stderr || stdout));
    }

    return ok(stdout.trim());
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      return err(errorFactory(command, 'Aborted'));
    }
    return err(errorFactory(command, String(error)));
  }
}

/**
 * Wrap a command string with NVM sourcing.
 *
 * @param command - The command to wrap
 * @param options.bashWrap - If true, wraps in `bash -c '...'` with single-quote escaping.
 *   Use for commands passed to /usr/bin/time or other outer shells.
 *   If false (default), just prepends the NVM export prefix.
 *   Use for hyperfine which handles its own shell.
 */
export function wrapCommandWithNvm(command: string, options?: { bashWrap?: boolean }): string {
  const nvmPrefix = 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh";';

  if (options?.bashWrap) {
    return `bash -c '${nvmPrefix} ${command.replace(/'/g, "'\\''")} '`;
  }

  return `${nvmPrefix} ${command}`;
}
