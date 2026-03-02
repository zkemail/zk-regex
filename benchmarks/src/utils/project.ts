/**
 * Project root and git helpers.
 */

import * as path from 'path';

/**
 * Resolve the zk-regex project root.
 *
 * From benchmarks/src/utils/ that's 3 levels up.
 */
export function getProjectRoot(): string {
  return path.resolve(import.meta.dir, '..', '..', '..');
}

/**
 * Get current git HEAD commit hash.
 */
export function getGitCommitHash(): string {
  try {
    const result = Bun.spawnSync(['git', 'rev-parse', 'HEAD']);
    return result.stdout.toString().trim() || 'unknown';
  } catch {
    console.warn('Warning: Could not determine git commit hash');
    return 'unknown';
  }
}
