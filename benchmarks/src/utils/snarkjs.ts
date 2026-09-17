/**
 * snarkjs integration for R1CS constraint extraction and proving.
 *
 * Uses CLI instead of programmatic API due to Bun compatibility issues
 * with snarkjs's web workers.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import type { TimingStats } from '../types.js';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import { execAsync } from './exec.js';
import { calculateStats } from './timing.js';

const snarkjsExecOptions = { useNvm: true } as const;

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

  const result = await execAsync(`npx snarkjs r1cs info "${r1csPath}"`, snarkjsExecOptions);
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
  const result1 = await execAsync(
    `npx snarkjs groth16 setup "${r1csPath}" "${ptauPath}" "${zkeyInitPath}"`,
    snarkjsExecOptions
  );
  if (!result1.ok) {
    return result1;
  }

  // Phase 2: Contribute entropy
  const result2 = await execAsync(
    `npx snarkjs zkey contribute "${zkeyInitPath}" "${zkeyPath}" --name=benchmark -e=random_entropy`,
    snarkjsExecOptions
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
  const result = await execAsync(
    `npx snarkjs zkey export verificationkey "${zkeyPath}" "${vkeyPath}"`,
    snarkjsExecOptions
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
  const result = await execAsync(
    `npx snarkjs wtns calculate "${wasmPath}" "${inputPath}" "${witnessPath}"`,
    snarkjsExecOptions
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

  const result = await execAsync(
    `npx snarkjs groth16 prove "${zkeyPath}" "${witnessPath}" "${finalProofPath}" "${finalPublicPath}"`,
    snarkjsExecOptions
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

    const result = await execAsync(
      `npx snarkjs groth16 verify "${vkeyPath}" "${tempPublicPath}" "${tempProofPath}"`,
      snarkjsExecOptions
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
 * Measure witness generation timing over multiple runs.
 *
 * Fallback path used when runWithMemoryTracking() returns null.
 * Logs first failure to aid debugging and returns zero stats if all runs fail.
 */
export async function measureWitnessGeneration(
  wasmPath: string,
  inputPath: string,
  witnessPath: string,
  runs: number
): Promise<TimingStats> {
  const times: number[] = [];

  for (let i = 0; i < runs; i++) {
    const start = performance.now();
    const result = await generateWitness(wasmPath, inputPath, witnessPath);
    const end = performance.now();

    if (result.ok) {
      times.push(end - start);
    } else if (i === 0) {
      console.log(`      Warning: Witness generation failed`);
      if (result.error.kind === 'compilation_failed') {
        console.log(`        ${result.error.stderr.split('\n')[0]}`);
      }
    }
  }

  if (times.length === 0) {
    return { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 };
  }

  return calculateStats(times);
}
