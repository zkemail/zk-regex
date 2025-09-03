import { spawn, execSync, ExecSyncOptions, SpawnOptions } from 'child_process';
import { ProcessResult } from './types.js';
import { logger } from './logger.js';
import * as fs from 'fs';

/**
 * Execute a command synchronously and return the result
 */
export function executeCommand(
  command: string,
  args: string[],
  options: {
    cwd?: string;
    captureOutput?: boolean;
    timeout?: number;
  } = {}
): ProcessResult {
  try {
    const { cwd, captureOutput = true, timeout = 120000 } = options;
    
    logger.debug(`Executing: ${command} ${args.join(' ')}`, { cwd });

    if (captureOutput) {
      const result = execSync(`${command} ${args.join(' ')}`, {
        cwd,
        timeout,
        encoding: 'utf8',
      });
      
      return {
        success: true,
        stdout: result,
      };
    } else {
      // For non-captured output, use spawn to show real-time output
      execSync(`${command} ${args.join(' ')}`, {
        cwd,
        timeout,
        stdio: 'inherit',
      });
      
      return {
        success: true,
        stdout: undefined,
        stderr: undefined,
        error: undefined,
      };
    }
  } catch (error) {
    const err = error as Error & { stdout?: string; stderr?: string; status?: number };
    
    logger.error(`Command failed: ${command} ${args.join(' ')}`, {
      error: err.message,
      stdout: err.stdout,
      stderr: err.stderr,
      status: err.status,
    });

    return {
      success: false,
      stdout: err.stdout || undefined,
      stderr: err.stderr || undefined,
      error: err,
    };
  }
}

/**
 * Execute a command asynchronously
 */
export async function executeCommandAsync(
  command: string,
  args: string[],
  options: {
    cwd?: string;
    captureOutput?: boolean;
    timeout?: number;
  } = {}
): Promise<ProcessResult> {
  return new Promise((resolve) => {
    const { cwd, captureOutput = true, timeout = 120000 } = options;
    
    logger.debug(`Executing async: ${command} ${args.join(' ')}`, { cwd });

    const child = spawn(command, args, {
      cwd,
      stdio: captureOutput ? 'pipe' : 'inherit',
    });

    let stdout = '';
    let stderr = '';

    if (captureOutput) {
      child.stdout?.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr?.on('data', (data) => {
        stderr += data.toString();
      });
    }

    const timeoutId = setTimeout(() => {
      child.kill('SIGTERM');
      resolve({
        success: false,
        error: new Error(`Command timed out after ${timeout}ms`),
      });
    }, timeout);

    child.on('error', (error) => {
      clearTimeout(timeoutId);
      resolve({
        success: false,
        error,
      });
    });

    child.on('close', (code) => {
      clearTimeout(timeoutId);
      
      const success = code === 0;
      
      if (!success) {
        logger.error(`Async command failed: ${command} ${args.join(' ')}`, {
          code,
          stdout,
          stderr,
        });
      }

      resolve({
        success,
        stdout: captureOutput ? (stdout || undefined) : undefined,
        stderr: captureOutput ? (stderr || undefined) : undefined,
        error: success ? undefined : new Error(`Process exited with code ${code}`),
      });
    });
  });
}

/**
 * Execute multiple commands in parallel
 */
export async function executeCommandsParallel(
  commands: Array<{
    command: string;
    args: string[];
    options?: {
      cwd?: string;
      captureOutput?: boolean;
      timeout?: number;
    };
  }>
): Promise<ProcessResult[]> {
  const promises = commands.map(({ command, args, options }) =>
    executeCommandAsync(command, args, options)
  );

  return Promise.all(promises);
}

/**
 * Execute multiple commands in sequence (one after another)
 */
export async function executeCommandsSequence(
  commands: Array<{
    command: string;
    args: string[];
    options?: {
      cwd?: string;
      captureOutput?: boolean;
      timeout?: number;
    };
  }>
): Promise<ProcessResult[]> {
  const results: ProcessResult[] = [];

  for (const { command, args, options } of commands) {
    const result = await executeCommandAsync(command, args, options);
    results.push(result);
    
    // Stop if command failed
    if (!result.success) {
      break;
    }
  }

  return results;
}

/**
 * Execute a Cargo command with common options
 * Prefers using the release binary if available for better performance
 */
export function executeCargo(
  subcommand: string,
  args: string[],
  options: {
    cwd?: string;
    quiet?: boolean;
    showOutput?: boolean;
    preferReleaseBinary?: boolean;
  } = {}
): ProcessResult {
  const { cwd, quiet = false, showOutput = true, preferReleaseBinary = true } = options;
  
  // Check if we should use the release binary for better performance
  if (preferReleaseBinary && subcommand === 'run' && args.includes('--bin')) {
    const binIndex = args.indexOf('--bin');
    if (binIndex !== -1 && binIndex + 1 < args.length) {
      const binaryName = args[binIndex + 1];
      const releaseBinaryPath = cwd 
        ? `${cwd}/target/release/${binaryName}`
        : `target/release/${binaryName}`;
      
      // Check if release binary exists using fs for cross-platform compatibility
      try {
        const binaryExists = fs.existsSync(releaseBinaryPath);
        if (!binaryExists) {
          throw new Error('Binary not found');
        }
        
        // Use the release binary directly instead of cargo run
        const binaryArgs = args.slice(binIndex + 2); // Skip --bin and binary name
        const commandOptions: {
          cwd?: string;
          captureOutput?: boolean;
          timeout?: number;
        } = {
          captureOutput: !showOutput,
        };
        
        if (cwd) {
          commandOptions.cwd = cwd;
        }
        
        logger.debug(`Using release binary: ${releaseBinaryPath}`);
        return executeCommand(releaseBinaryPath, binaryArgs, commandOptions);
      } catch {
        // Release binary doesn't exist, fall back to cargo run
        logger.debug(`Release binary not found at ${releaseBinaryPath}, using cargo run`);
      }
    }
  }
  
  // Default cargo execution
  const cargoArgs = [subcommand];
  if (quiet) {
    cargoArgs.push('--quiet');
  }
  cargoArgs.push(...args);

  const commandOptions: {
    cwd?: string;
    captureOutput?: boolean;
    timeout?: number;
  } = {
    captureOutput: !showOutput,
  };
  
  if (cwd) {
    commandOptions.cwd = cwd;
  }

  return executeCommand('cargo', cargoArgs, commandOptions);
}

/**
 * Check if a command is available on the system
 */
export function isCommandAvailable(command: string): boolean {
  try {
    execSync(`which ${command}`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}