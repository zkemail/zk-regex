/**
 * Git worktree management for v1 benchmarking.
 *
 * Creates a temporary worktree from the main branch to benchmark
 * the v1 DFA-based compiler without affecting the current branch.
 */

import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs/promises';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';

const V1_WORKTREE_PATH = path.join(os.tmpdir(), 'zk-regex-v1-bench');

/**
 * Execute a command and return stdout.
 */
async function execAsync(
  command: string,
  options: { cwd?: string } = {}
): Promise<Result<string>> {
  try {
    // Source nvm to get yarn/npm/node in PATH
    const nvmCommand = `
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      ${command}
    `;

    // Filter out Bun's node shim paths (like /tmp/bun-node-*) that would
    // override nvm's node and cause npm/yarn commands to fail
    const cleanPath = (process.env.PATH || '')
      .split(':')
      .filter(p => !p.includes('bun-node'))
      .join(':');

    const proc = Bun.spawn(['bash', '-c', nvmCommand], {
      cwd: options.cwd,
      stdout: 'pipe',
      stderr: 'pipe',
      env: { ...process.env, PATH: cleanPath },
    });

    const stdout = await new Response(proc.stdout).text();
    const stderr = await new Response(proc.stderr).text();
    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      return err(errors.worktreeFailed('main', stderr));
    }

    return ok(stdout.trim());
  } catch (error) {
    return err(errors.worktreeFailed('main', String(error)));
  }
}

/**
 * Check if the worktree already exists.
 */
async function worktreeExists(): Promise<boolean> {
  try {
    await fs.access(V1_WORKTREE_PATH);
    return true;
  } catch {
    return false;
  }
}

/**
 * Set up a git worktree for v1 benchmarking.
 *
 * Creates a detached HEAD worktree from the main branch,
 * installs dependencies with Yarn, and builds the compiler.
 */
export async function setupV1Worktree(): Promise<Result<string>> {
  // Clean up any existing worktree first
  await cleanupV1Worktree();

  // Prune stale worktrees
  const pruneResult = await execAsync('git worktree prune');
  if (!pruneResult.ok) {
    console.warn('Warning: Failed to prune worktrees');
  }

  // Create worktree with detached HEAD (no branch association)
  console.log(`Creating v1 worktree at ${V1_WORKTREE_PATH}...`);
  const addResult = await execAsync(
    `git worktree add --detach "${V1_WORKTREE_PATH}" main`
  );
  if (!addResult.ok) {
    return addResult;
  }

  // Install dependencies with Yarn (v1 uses Yarn, not Bun)
  console.log('Installing v1 dependencies with Yarn...');
  const yarnResult = await execAsync('yarn install', { cwd: V1_WORKTREE_PATH });
  if (!yarnResult.ok) {
    await cleanupV1Worktree();
    return yarnResult;
  }

  // Build the v1 compiler
  console.log('Building v1 compiler...');
  const buildResult = await execAsync('yarn build', { cwd: V1_WORKTREE_PATH });
  if (!buildResult.ok) {
    await cleanupV1Worktree();
    return buildResult;
  }

  console.log('v1 worktree ready');
  return ok(V1_WORKTREE_PATH);
}

/**
 * Get the path to the v1 worktree.
 */
export function getV1WorktreePath(): string {
  return V1_WORKTREE_PATH;
}

/**
 * Get the path to a v1 circuit file.
 */
export function getV1CircuitPath(circuitName: string): string {
  return path.join(
    V1_WORKTREE_PATH,
    'packages',
    'circom',
    'circuits',
    'common',
    `${circuitName}.circom`
  );
}

/**
 * Clean up the v1 worktree.
 */
export async function cleanupV1Worktree(): Promise<void> {
  if (await worktreeExists()) {
    console.log('Cleaning up v1 worktree...');
    await execAsync(`git worktree remove --force "${V1_WORKTREE_PATH}"`);
  }
  await execAsync('git worktree prune');
}

/**
 * Register cleanup handler for process exit.
 *
 * Ensures worktree is removed even if the process crashes.
 */
export function registerCleanupHandler(): void {
  const cleanup = async () => {
    await cleanupV1Worktree();
    process.exit();
  };

  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);
  process.on('uncaughtException', async (error) => {
    console.error('Uncaught exception:', error);
    await cleanupV1Worktree();
    process.exit(1);
  });
}
