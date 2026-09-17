/**
 * Centralized abort/signal handling for benchmark suite.
 *
 * Uses AbortController to coordinate graceful shutdown:
 * - SIGINT/SIGTERM abort the controller
 * - All Bun.spawn processes receive the abort signal
 * - Benchmark loops check isAborted() to break early
 * - Normal control flow unwinds through finally blocks
 */

const controller = new AbortController();
let interrupted = false;

/** Get the AbortSignal for passing to Bun.spawn and loops. */
export function getAbortSignal(): AbortSignal {
  return controller.signal;
}

/** Check if the benchmark suite has been interrupted. */
export function isAborted(): boolean {
  return controller.signal.aborted;
}

/**
 * Register SIGINT/SIGTERM handlers for graceful shutdown.
 *
 * First Ctrl+C: aborts the controller (kills children, breaks loops)
 * Second Ctrl+C: force exits immediately
 */
export function registerAbortHandler(onCleanup?: () => Promise<void>): void {
  const handler = async () => {
    if (interrupted) {
      // Second interrupt — force exit
      console.log('\nForce exit.');
      if (onCleanup) await onCleanup();
      process.exit(130);
    }

    interrupted = true;
    console.log('\nInterrupted — shutting down (press Ctrl+C again to force)...');
    controller.abort();

    // Don't call process.exit() — let the normal flow unwind through
    // finally blocks so provider.cleanup() runs naturally.
  };

  process.on('SIGINT', handler);
  process.on('SIGTERM', handler);
}
