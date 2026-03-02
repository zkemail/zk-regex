/**
 * Error handling for ZK-Regex benchmarks using discriminated unions.
 *
 * This approach provides type-safe error handling without exceptions,
 * making error states explicit in function signatures.
 */

/**
 * Discriminated union of all benchmark error types.
 */
export type BenchmarkError =
  | { readonly kind: 'missing_binary'; readonly binary: string; readonly installHint: string }
  | { readonly kind: 'compilation_failed'; readonly pattern: string; readonly stderr: string }
  | { readonly kind: 'timeout'; readonly pattern: string; readonly timeoutMs: number }
  | { readonly kind: 'invalid_output'; readonly tool: string; readonly rawOutput: string }
  | { readonly kind: 'worktree_failed'; readonly branch: string; readonly error: string }
  | { readonly kind: 'ptau_download_failed'; readonly url: string; readonly error: string }
  | { readonly kind: 'file_not_found'; readonly path: string }
  | { readonly kind: 'parse_error'; readonly message: string; readonly rawData: string }
  | { readonly kind: 'hyperfine_failed'; readonly command: string; readonly error: string };

/**
 * Result type for operations that can fail.
 */
export type Result<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: BenchmarkError };

/**
 * Create a successful result.
 */
export function ok<T>(value: T): Result<T> {
  return { ok: true, value };
}

/**
 * Create a failed result.
 */
export function err<T>(error: BenchmarkError): Result<T> {
  return { ok: false, error };
}

/**
 * Format an error for display.
 */
export function formatError(error: BenchmarkError): string {
  switch (error.kind) {
    case 'missing_binary':
      return `Missing binary: ${error.binary}\nInstall with: ${error.installHint}`;

    case 'compilation_failed':
      return `Compilation failed for pattern '${error.pattern}':\n${error.stderr}`;

    case 'timeout':
      return `Benchmark timed out for pattern '${error.pattern}' after ${error.timeoutMs}ms`;

    case 'invalid_output':
      return `Invalid output from ${error.tool}:\n${error.rawOutput}`;

    case 'worktree_failed':
      return `Failed to set up worktree for branch '${error.branch}': ${error.error}`;

    case 'ptau_download_failed':
      return `Failed to download Powers of Tau from ${error.url}: ${error.error}`;

    case 'file_not_found':
      return `File not found: ${error.path}`;

    case 'parse_error':
      return `Parse error: ${error.message}\nRaw data: ${error.rawData}`;

    case 'hyperfine_failed':
      return `Hyperfine benchmark failed for command '${error.command}': ${error.error}`;
  }
}

/**
 * Error factory functions for common error types.
 */
export const errors = {
  missingBinary: (binary: string, installHint: string): BenchmarkError => ({
    kind: 'missing_binary',
    binary,
    installHint,
  }),

  compilationFailed: (pattern: string, stderr: string): BenchmarkError => ({
    kind: 'compilation_failed',
    pattern,
    stderr,
  }),

  timeout: (pattern: string, timeoutMs: number): BenchmarkError => ({
    kind: 'timeout',
    pattern,
    timeoutMs,
  }),

  invalidOutput: (tool: string, rawOutput: string): BenchmarkError => ({
    kind: 'invalid_output',
    tool,
    rawOutput,
  }),

  worktreeFailed: (branch: string, error: string): BenchmarkError => ({
    kind: 'worktree_failed',
    branch,
    error,
  }),

  ptauDownloadFailed: (url: string, error: string): BenchmarkError => ({
    kind: 'ptau_download_failed',
    url,
    error,
  }),

  fileNotFound: (path: string): BenchmarkError => ({
    kind: 'file_not_found',
    path,
  }),

  parseError: (message: string, rawData: string): BenchmarkError => ({
    kind: 'parse_error',
    message,
    rawData,
  }),

  hyperfineFailed: (command: string, error: string): BenchmarkError => ({
    kind: 'hyperfine_failed',
    command,
    error,
  }),
};
