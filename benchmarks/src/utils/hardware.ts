/**
 * Hardware and system information collection for reproducibility.
 */

import * as os from 'os';
import type { HardwareSpec, ToolVersions } from '../types.js';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';

/**
 * Collect hardware specifications.
 */
export function getHardwareSpec(): HardwareSpec {
  const cpus = os.cpus();

  return {
    platform: os.platform(),
    cpu: cpus[0]?.model ?? 'Unknown',
    cores: cpus.length,
    memoryGB: Math.round(os.totalmem() / (1024 ** 3)),
    os: `${os.type()} ${os.release()}`,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Execute a command and capture output.
 */
async function execCommand(command: string): Promise<Result<string>> {
  try {
    const proc = Bun.spawn(['sh', '-c', command], {
      stdout: 'pipe',
      stderr: 'pipe',
    });

    const output = await new Response(proc.stdout).text();
    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      const stderr = await new Response(proc.stderr).text();
      return err(errors.invalidOutput(command, stderr));
    }

    return ok(output.trim());
  } catch (error) {
    return err(errors.invalidOutput(command, String(error)));
  }
}

/**
 * Get version of a tool.
 */
async function getVersion(command: string): Promise<string | undefined> {
  const result = await execCommand(command);
  return result.ok ? result.value : undefined;
}

/**
 * Collect tool versions for reproducibility.
 */
export async function getToolVersions(): Promise<ToolVersions> {
  const [circom, snarkjs, nargo, bb] = await Promise.all([
    getVersion('circom --version 2>/dev/null | head -1'),
    getVersion('snarkjs --version 2>/dev/null'),
    getVersion('nargo --version 2>/dev/null | head -1'),
    getVersion('bb --version 2>/dev/null | head -1'),
  ]);

  return {
    circom,
    snarkjs,
    nargo,
    barretenberg: bb,
    bun: Bun.version,
    node: process.version,
  };
}

/**
 * Check if a binary is available.
 */
export async function checkBinaryExists(binary: string): Promise<boolean> {
  const result = await execCommand(`which ${binary}`);
  return result.ok;
}

/**
 * Verify required binaries are available.
 */
export async function verifyDependencies(
  binaries: string[]
): Promise<Result<void>> {
  for (const binary of binaries) {
    const exists = await checkBinaryExists(binary);
    if (!exists) {
      return err(
        errors.missingBinary(
          binary,
          getInstallHint(binary)
        )
      );
    }
  }
  return ok(undefined);
}

/**
 * Get installation hint for a binary.
 */
function getInstallHint(binary: string): string {
  const hints: Record<string, string> = {
    circom: 'cargo install circom',
    snarkjs: 'npm install -g snarkjs',
    nargo: 'curl -L https://raw.githubusercontent.com/noir-lang/noirup/refs/heads/main/install | bash && noirup',
    bb: 'Installed with nargo via noirup',
    hyperfine: 'brew install hyperfine (macOS) or apt install hyperfine (Linux)',
    yarn: 'npm install -g yarn',
  };

  return hints[binary] ?? `Install ${binary}`;
}
