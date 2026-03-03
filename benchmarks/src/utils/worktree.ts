/**
 * Git worktree management for DFA benchmarking.
 *
 * Creates a temporary worktree from the main branch to benchmark
 * the DFA-based compiler without affecting the current branch.
 */

import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs/promises';
import type { Result } from '../errors.js';
import { ok, errors } from '../errors.js';
import { execAsync } from './exec.js';

const BENCHMARK_CONFIG_PATH = path.join(import.meta.dir, '..', '..', 'config', 'benchmark.json');

const DFA_WORKTREE_PATH = path.join(os.tmpdir(), 'zk-regex-dfa-bench');

const worktreeExecOptions = {
  useNvm: true,
  errorFactory: (_cmd: string, stderr: string) => errors.worktreeFailed('main', stderr),
} as const;

/**
 * Check if the worktree already exists.
 */
async function worktreeExists(): Promise<boolean> {
  try {
    await fs.access(DFA_WORKTREE_PATH);
    return true;
  } catch {
    return false;
  }
}

/**
 * Validate a string is a safe git ref (commit hash or branch name).
 * Allows: hex SHAs, or simple branch names (alphanumeric, -, _, /, .).
 */
function isValidGitRef(ref: string): boolean {
  return /^[a-zA-Z0-9._\/-]+$/.test(ref) && ref.length <= 255;
}

/**
 * Read the DFA compiler commit hash from benchmark config.
 * Falls back to 'main' if no commit hash is configured.
 */
async function getDfaCommitRef(): Promise<string> {
  try {
    const content = await fs.readFile(BENCHMARK_CONFIG_PATH, 'utf-8');
    const config = JSON.parse(content);
    const commitHash = config?.providers?.['circom-dfa']?.commitHash;
    if (commitHash && isValidGitRef(commitHash)) {
      return commitHash;
    }
    if (commitHash) {
      console.error(`Invalid DFA commit hash in benchmark.json: ${commitHash}`);
    }
  } catch {
    // Fall back to main if config cannot be read
  }
  console.warn('Warning: No DFA commit hash in benchmark.json, falling back to main');
  return 'main';
}

/**
 * Set up a git worktree for DFA benchmarking.
 *
 * Creates a detached HEAD worktree from the configured commit hash
 * (or main branch as fallback), installs dependencies with Yarn,
 * and builds the compiler.
 */
export async function setupDfaWorktree(): Promise<Result<string>> {
  // Clean up any existing worktree first
  await cleanupDfaWorktree();

  // Prune stale worktrees
  const pruneResult = await execAsync('git worktree prune', worktreeExecOptions);
  if (!pruneResult.ok) {
    console.warn('Warning: Failed to prune worktrees');
  }

  // Get the commit reference to use
  const commitRef = await getDfaCommitRef();
  console.log(`Using DFA ref: ${commitRef}`);

  // Create worktree with detached HEAD
  console.log(`Creating DFA worktree at ${DFA_WORKTREE_PATH}...`);
  const addResult = await execAsync(
    `git worktree add --detach "${DFA_WORKTREE_PATH}" "${commitRef}"`,
    worktreeExecOptions
  );
  if (!addResult.ok) {
    return addResult;
  }

  // Install dependencies with Yarn (DFA codebase uses Yarn, not Bun)
  console.log('Installing DFA dependencies with Yarn...');
  const yarnResult = await execAsync('yarn install', { ...worktreeExecOptions, cwd: DFA_WORKTREE_PATH });
  if (!yarnResult.ok) {
    await cleanupDfaWorktree();
    return yarnResult;
  }

  // Build the DFA compiler
  console.log('Building DFA compiler...');
  const buildResult = await execAsync('yarn build', { ...worktreeExecOptions, cwd: DFA_WORKTREE_PATH });
  if (!buildResult.ok) {
    await cleanupDfaWorktree();
    return buildResult;
  }

  console.log('DFA worktree ready');
  return ok(DFA_WORKTREE_PATH);
}

/**
 * Get the path to the DFA worktree.
 */
export function getDfaWorktreePath(): string {
  return DFA_WORKTREE_PATH;
}

/**
 * Get the path to a DFA circuit file.
 */
export function getDfaCircuitPath(circuitName: string): string {
  return path.join(
    DFA_WORKTREE_PATH,
    'packages',
    'circom',
    'circuits',
    'common',
    `${circuitName}.circom`
  );
}

/**
 * Clean up the DFA worktree.
 */
export async function cleanupDfaWorktree(): Promise<void> {
  if (await worktreeExists()) {
    console.log('Cleaning up DFA worktree...');
    await execAsync(`git worktree remove --force "${DFA_WORKTREE_PATH}"`, worktreeExecOptions);
  }
  await execAsync('git worktree prune', worktreeExecOptions);
}

