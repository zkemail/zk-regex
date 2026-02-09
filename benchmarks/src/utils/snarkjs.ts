/**
 * snarkjs integration for R1CS constraint extraction and proving.
 *
 * Uses the programmatic API for better integration and error handling.
 */

import * as fs from 'fs/promises';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';

// snarkjs is CommonJS without types, define minimal interface
interface SnarkjsR1csInfo {
  nConstraints: bigint | number;
}

interface Snarkjs {
  r1cs: {
    info(r1csPath: string, logger?: Console): Promise<SnarkjsR1csInfo>;
  };
  zKey: {
    newZKey(r1csPath: string, ptauPath: string, zkeyPath: string, logger?: Console): Promise<void>;
    contribute(zkeyPath: string, zkeyFinalPath: string, name: string, entropy: string): Promise<void>;
    exportVerificationKey(zkeyPath: string): Promise<unknown>;
  };
  groth16: {
    prove(zkeyPath: string, witnessPath: string): Promise<{ proof: unknown; publicSignals: string[] }>;
    verify(vkey: unknown, publicSignals: string[], proof: unknown): Promise<boolean>;
  };
  wtns: {
    calculate(wasm: Buffer, input: unknown, witnessPath: string): Promise<void>;
  };
}

// snarkjs is CommonJS, use dynamic import
let snarkjs: Snarkjs | null = null;

async function getSnarkjs(): Promise<Snarkjs> {
  if (!snarkjs) {
    // @ts-expect-error snarkjs has no type declarations
    snarkjs = await import('snarkjs');
  }
  return snarkjs!;
}

/**
 * Get the constraint count from an R1CS file.
 */
export async function getConstraintCount(r1csPath: string): Promise<Result<number>> {
  try {
    await fs.access(r1csPath);
  } catch {
    return err(errors.fileNotFound(r1csPath));
  }

  try {
    const snarky = await getSnarkjs();
    const r1csInfo = await snarky.r1cs.info(r1csPath, console);
    return ok(Number(r1csInfo.nConstraints));
  } catch (error) {
    return err(errors.invalidOutput('snarkjs', String(error)));
  }
}

/**
 * Full Groth16 setup (create zkey from R1CS and Powers of Tau).
 *
 * This is expensive (30s-5min). Cache the result.
 */
export async function groth16Setup(
  r1csPath: string,
  ptauPath: string,
  zkeyPath: string
): Promise<Result<void>> {
  try {
    const snarky = await getSnarkjs();

    // Phase 1: Create zkey
    await snarky.zKey.newZKey(r1csPath, ptauPath, zkeyPath, console);

    // Phase 2: Contribute entropy
    const zkeyFinalPath = zkeyPath.replace('.zkey', '_final.zkey');
    await snarky.zKey.contribute(
      zkeyPath,
      zkeyFinalPath,
      'benchmark',
      'random_entropy_for_benchmark'
    );

    // Replace original with final
    await fs.rename(zkeyFinalPath, zkeyPath);

    return ok(undefined);
  } catch (error) {
    return err(errors.compilationFailed('zkey setup', String(error)));
  }
}

/**
 * Export verification key from zkey.
 */
export async function exportVkey(
  zkeyPath: string,
  vkeyPath: string
): Promise<Result<void>> {
  try {
    const snarky = await getSnarkjs();
    const vkey = await snarky.zKey.exportVerificationKey(zkeyPath);
    await fs.writeFile(vkeyPath, JSON.stringify(vkey, null, 2));
    return ok(undefined);
  } catch (error) {
    return err(errors.invalidOutput('snarkjs exportVkey', String(error)));
  }
}

/**
 * Generate witness using the WASM circuit.
 */
export async function generateWitness(
  wasmPath: string,
  inputPath: string,
  witnessPath: string
): Promise<Result<void>> {
  try {
    const snarky = await getSnarkjs();
    const input = JSON.parse(await fs.readFile(inputPath, 'utf-8'));
    await snarky.wtns.calculate(await fs.readFile(wasmPath), input, witnessPath);
    return ok(undefined);
  } catch (error) {
    return err(errors.compilationFailed('witness generation', String(error)));
  }
}

/**
 * Generate and verify a Groth16 proof.
 *
 * Returns the proof and public signals.
 */
export async function proveAndVerify(
  zkeyPath: string,
  witnessPath: string,
  vkeyPath: string
): Promise<Result<{ proof: unknown; publicSignals: string[]; verified: boolean }>> {
  try {
    const snarky = await getSnarkjs();

    // Generate proof
    const { proof, publicSignals } = await snarky.groth16.prove(zkeyPath, witnessPath);

    // Verify proof
    const vkey = JSON.parse(await fs.readFile(vkeyPath, 'utf-8'));
    const verified = await snarky.groth16.verify(vkey, publicSignals, proof);

    return ok({ proof, publicSignals, verified });
  } catch (error) {
    return err(errors.compilationFailed('prove/verify', String(error)));
  }
}

/**
 * Just generate proof (for timing).
 */
export async function prove(
  zkeyPath: string,
  witnessPath: string
): Promise<Result<{ proof: unknown; publicSignals: string[] }>> {
  try {
    const snarky = await getSnarkjs();
    const result = await snarky.groth16.prove(zkeyPath, witnessPath);
    return ok(result);
  } catch (error) {
    return err(errors.compilationFailed('prove', String(error)));
  }
}

/**
 * Just verify proof (for timing).
 */
export async function verify(
  vkeyPath: string,
  publicSignals: string[],
  proof: unknown
): Promise<Result<boolean>> {
  try {
    const snarky = await getSnarkjs();
    const vkey = JSON.parse(await fs.readFile(vkeyPath, 'utf-8'));
    const verified = await snarky.groth16.verify(vkey, publicSignals, proof);
    return ok(verified);
  } catch (error) {
    return err(errors.invalidOutput('snarkjs verify', String(error)));
  }
}
