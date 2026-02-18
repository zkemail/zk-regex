/**
 * snarkjs integration for R1CS constraint extraction and proving.
 *
 * Uses CLI instead of programmatic API due to Bun compatibility issues
 * with snarkjs's web workers.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import { getAbortSignal } from './abort.js';

/**
 * Get the constraint count from an R1CS file using CLI.
 *
 * Note: We use CLI instead of programmatic API due to Bun compatibility
 * issues with snarkjs's web workers.
 */
export async function getConstraintCount(r1csPath: string): Promise<Result<number>> {
  try {
    await fs.access(r1csPath);
  } catch {
    return err(errors.fileNotFound(r1csPath));
  }

  const result = await execCommand(`npx snarkjs r1cs info "${r1csPath}"`);
  if (!result.ok) {
    return result;
  }

  // Parse constraint count from output like "# of Constraints: 12345"
  const match = result.value.match(/# of Constraints:\s+(\d+)/i);
  if (!match) {
    return err(errors.invalidOutput('snarkjs r1cs info', result.value));
  }

  return ok(parseInt(match[1], 10));
}

/**
 * Execute a CLI command and return result.
 * Sources nvm to ensure npx is available, then runs the command.
 */
async function execCommand(
  command: string,
  options: { cwd?: string } = {}
): Promise<Result<string>> {
  try {
    // Source nvm to get npx/node in PATH, then run the command
    // IMPORTANT: Filter out Bun's node shim paths from PATH to avoid conflicts with npm/npx
    const nvmCommand = `
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      ${command}
    `;

    // Filter out Bun's node shim paths (like /tmp/bun-node-*) that would
    // override nvm's node and cause npm/npx to fail
    const cleanPath = (process.env.PATH || '')
      .split(':')
      .filter(p => !p.includes('bun-node'))
      .join(':');

    const proc = Bun.spawn(['bash', '-c', nvmCommand], {
      cwd: options.cwd,
      stdout: 'pipe',
      stderr: 'pipe',
      env: { ...process.env, PATH: cleanPath },
      signal: getAbortSignal(),
    });

    const stdout = await new Response(proc.stdout).text();
    const stderr = await new Response(proc.stderr).text();
    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      return err(errors.compilationFailed(command, stderr || stdout));
    }

    return ok(stdout.trim());
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      return err(errors.compilationFailed(command, 'Aborted'));
    }
    return err(errors.compilationFailed(command, String(error)));
  }
}

/**
 * Full Groth16 setup (create zkey from R1CS and Powers of Tau) using CLI.
 *
 * This is expensive (30s-5min). Cache the result.
 */
export async function groth16Setup(
  r1csPath: string,
  ptauPath: string,
  zkeyPath: string
): Promise<Result<void>> {
  // Phase 1: Create zkey (initial ceremony)
  const zkeyInitPath = zkeyPath.replace('.zkey', '_init.zkey');
  const result1 = await execCommand(
    `npx snarkjs groth16 setup "${r1csPath}" "${ptauPath}" "${zkeyInitPath}"`
  );
  if (!result1.ok) {
    return result1;
  }

  // Phase 2: Contribute entropy
  const result2 = await execCommand(
    `npx snarkjs zkey contribute "${zkeyInitPath}" "${zkeyPath}" --name=benchmark -e=random_entropy`
  );
  if (!result2.ok) {
    return result2;
  }

  // Clean up intermediate file
  await fs.unlink(zkeyInitPath).catch(() => {});

  return ok(undefined);
}

/**
 * Export verification key from zkey using CLI.
 */
export async function exportVkey(
  zkeyPath: string,
  vkeyPath: string
): Promise<Result<void>> {
  const result = await execCommand(
    `npx snarkjs zkey export verificationkey "${zkeyPath}" "${vkeyPath}"`
  );
  if (!result.ok) {
    return result;
  }
  return ok(undefined);
}

/**
 * Generate witness using CLI.
 *
 * Uses snarkjs wtns calculate via CLI to avoid Bun worker issues.
 */
export async function generateWitness(
  wasmPath: string,
  inputPath: string,
  witnessPath: string
): Promise<Result<void>> {
  const result = await execCommand(
    `npx snarkjs wtns calculate "${wasmPath}" "${inputPath}" "${witnessPath}"`
  );
  if (!result.ok) {
    return result;
  }
  return ok(undefined);
}

/**
 * Generate proof using CLI.
 *
 * Runs snarkjs groth16 prove and outputs to proof.json and public.json.
 */
export async function prove(
  zkeyPath: string,
  witnessPath: string,
  proofPath?: string,
  publicPath?: string
): Promise<Result<{ proof: unknown; publicSignals: string[] }>> {
  const dir = path.dirname(zkeyPath);
  const finalProofPath = proofPath ?? path.join(dir, 'proof.json');
  const finalPublicPath = publicPath ?? path.join(dir, 'public.json');

  const result = await execCommand(
    `npx snarkjs groth16 prove "${zkeyPath}" "${witnessPath}" "${finalProofPath}" "${finalPublicPath}"`
  );

  if (!result.ok) {
    return result;
  }

  try {
    const proof = JSON.parse(await fs.readFile(finalProofPath, 'utf-8'));
    const publicSignals = JSON.parse(await fs.readFile(finalPublicPath, 'utf-8'));
    return ok({ proof, publicSignals });
  } catch (error) {
    return err(errors.invalidOutput('snarkjs prove', String(error)));
  }
}

/**
 * Verify proof using CLI.
 */
export async function verify(
  vkeyPath: string,
  publicSignals: string[],
  proof: unknown
): Promise<Result<boolean>> {
  const dir = path.dirname(vkeyPath);
  const tempProofPath = path.join(dir, 'temp_proof.json');
  const tempPublicPath = path.join(dir, 'temp_public.json');

  try {
    // Write temporary files for CLI
    await fs.writeFile(tempProofPath, JSON.stringify(proof, null, 2));
    await fs.writeFile(tempPublicPath, JSON.stringify(publicSignals, null, 2));

    const result = await execCommand(
      `npx snarkjs groth16 verify "${vkeyPath}" "${tempPublicPath}" "${tempProofPath}"`
    );

    // Clean up temp files
    await fs.unlink(tempProofPath).catch(() => {});
    await fs.unlink(tempPublicPath).catch(() => {});

    if (!result.ok) {
      return result;
    }

    // Parse verification result - snarkjs outputs "OK!" or "INVALID"
    const verified = result.value.includes('OK!');
    return ok(verified);
  } catch (error) {
    return err(errors.invalidOutput('snarkjs verify', String(error)));
  }
}

/**
 * Generate and verify a Groth16 proof using CLI.
 *
 * Returns the proof and public signals.
 */
export async function proveAndVerify(
  zkeyPath: string,
  witnessPath: string,
  vkeyPath: string
): Promise<Result<{ proof: unknown; publicSignals: string[]; verified: boolean }>> {
  const proveResult = await prove(zkeyPath, witnessPath);
  if (!proveResult.ok) {
    return proveResult;
  }

  const { proof, publicSignals } = proveResult.value;

  const verifyResult = await verify(vkeyPath, publicSignals, proof);
  if (!verifyResult.ok) {
    return verifyResult;
  }

  return ok({ proof, publicSignals, verified: verifyResult.value });
}
