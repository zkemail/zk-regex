/**
 * Circom v1 (DFA-based) benchmark provider.
 *
 * This provider creates a git worktree of the main branch to benchmark
 * the v1 DFA-based compiler against the current v2 implementation.
 */

import * as path from 'path';
import * as fs from 'fs/promises';
import * as os from 'os';
import type {
  CircomMetrics,
  PatternDefinition,
  BenchmarkConfig,
  TimingStats,
} from '../types.js';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import { BaseBenchmarkProvider, type BenchmarkMetrics } from './base.js';
import {
  setupV1Worktree,
  cleanupV1Worktree,
  getV1WorktreePath,
  getV1CircuitPath,
} from '../utils/worktree.js';
import { ensurePtauFile, getMaxConstraints } from '../utils/ptau.js';
import { getConstraintCount, groth16Setup, generateWitness, prove, verify, exportVkey } from '../utils/snarkjs.js';
import { runHyperfine } from '../utils/hyperfine.js';
import { measureAsync, calculateStats } from '../utils/timing.js';

/**
 * Execute a shell command and return result.
 */
async function execAsync(
  command: string,
  options: { cwd?: string; timeout?: number } = {}
): Promise<Result<string>> {
  try {
    const proc = Bun.spawn(['sh', '-c', command], {
      cwd: options.cwd,
      stdout: 'pipe',
      stderr: 'pipe',
    });

    const stdout = await new Response(proc.stdout).text();
    const stderr = await new Response(proc.stderr).text();
    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      return err(errors.compilationFailed(command, stderr || stdout));
    }

    return ok(stdout.trim());
  } catch (error) {
    return err(errors.compilationFailed(command, String(error)));
  }
}

export class CircomV1Provider extends BaseBenchmarkProvider {
  readonly name = 'circom-v1';
  private worktreePath: string | null = null;
  private ptauPath: string | null = null;
  private buildDir: string;

  constructor() {
    super();
    this.buildDir = path.join(os.tmpdir(), 'zk-regex-v1-build');
  }

  async setup(): Promise<Result<void>> {
    console.log('Setting up Circom v1 provider...');

    // 1. Set up worktree from main branch
    const worktreeResult = await setupV1Worktree();
    if (!worktreeResult.ok) {
      return err(worktreeResult.error);
    }
    this.worktreePath = worktreeResult.value;
    console.log(`  Worktree ready at: ${this.worktreePath}`);

    // 2. Download/cache Powers of Tau
    const ptauResult = await ensurePtauFile();
    if (!ptauResult.ok) {
      return err(ptauResult.error);
    }
    this.ptauPath = ptauResult.value;
    console.log(`  Powers of Tau ready: ${this.ptauPath}`);

    // 3. Create build directory
    try {
      await fs.mkdir(this.buildDir, { recursive: true });
    } catch {
      // Directory might already exist
    }

    console.log('  Circom v1 provider setup complete');
    return ok(undefined);
  }

  async benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>> {
    if (!this.supportsPattern(pattern)) {
      return err(errors.compilationFailed(pattern.name, 'Pattern not available in v1'));
    }

    if (!this.worktreePath || !this.ptauPath) {
      return err(errors.compilationFailed(pattern.name, 'Provider not initialized'));
    }

    const circuitPath = getV1CircuitPath(pattern.circuitName);

    // Check if circuit exists
    try {
      await fs.access(circuitPath);
    } catch {
      return err(errors.fileNotFound(circuitPath));
    }

    // Create pattern-specific build directory
    const patternBuildDir = path.join(this.buildDir, `${pattern.circuitName}_${inputLengthBytes}`);
    await fs.mkdir(patternBuildDir, { recursive: true });

    // 1. Create wrapper circuit that instantiates the template as main
    // The v1 templates don't have a main component, just a template definition
    const templateName = pattern.circuitName
      .split('_')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join('');

    const wrapperName = `${pattern.circuitName}_wrapper`;
    const wrapperPath = path.join(patternBuildDir, `${wrapperName}.circom`);

    // v1 circuits use msg_bytes parameter and msg input
    const wrapperCode = `pragma circom 2.1.5;

include "${circuitPath}";

component main {public [msg]} = ${templateName}(${inputLengthBytes});
`;
    await fs.writeFile(wrapperPath, wrapperCode);

    // 2. Compile wrapper circuit
    console.log(`    Compiling ${pattern.circuitName}...`);
    const r1csPath = path.join(patternBuildDir, `${wrapperName}.r1cs`);
    const wasmDir = path.join(patternBuildDir, `${wrapperName}_js`);
    const wasmPath = path.join(wasmDir, `${wrapperName}.wasm`);

    // Include node_modules for @zk-email/zk-regex-circom imports
    const nodeModulesDir = path.join(this.worktreePath, 'node_modules');
    const compileResult = await execAsync(
      `circom "${wrapperPath}" --r1cs --wasm -l "${nodeModulesDir}" -o "${patternBuildDir}"`,
      { cwd: this.worktreePath }
    );
    if (!compileResult.ok) {
      return compileResult;
    }

    // 2. Get constraint count
    console.log(`    Getting constraint count...`);
    const constraintResult = await getConstraintCount(r1csPath);
    if (!constraintResult.ok) {
      return constraintResult;
    }
    const constraints = constraintResult.value;
    console.log(`    Constraints: ${constraints}`);

    // Check if constraints exceed ptau limit
    const maxConstraints = await getMaxConstraints();
    if (constraints > maxConstraints) {
      return err(
        errors.compilationFailed(
          pattern.name,
          `Constraint count ${constraints} exceeds ptau limit ${maxConstraints}. Use a larger ptau file.`
        )
      );
    }

    // 3. Generate test input
    const inputPath = path.join(patternBuildDir, 'input.json');
    const testInput = this.generateTestInput(pattern, inputLengthBytes);
    await fs.writeFile(inputPath, JSON.stringify(testInput, null, 2));

    // 4. Setup Groth16 (zkey)
    console.log(`    Setting up Groth16 (this may take a while)...`);
    const zkeyPath = path.join(patternBuildDir, `${wrapperName}.zkey`);
    const vkeyPath = path.join(patternBuildDir, `${wrapperName}.vkey.json`);

    // Check if cached
    try {
      await fs.access(zkeyPath);
      console.log(`    Using cached zkey`);
    } catch {
      const setupResult = await groth16Setup(r1csPath, this.ptauPath, zkeyPath);
      if (!setupResult.ok) {
        return setupResult;
      }
    }

    // Export verification key
    const vkeyResult = await exportVkey(zkeyPath, vkeyPath);
    if (!vkeyResult.ok) {
      return vkeyResult;
    }

    // 5. Measure witness generation
    console.log(`    Measuring witness generation (${config.minRuns} runs)...`);
    const witnessPath = path.join(patternBuildDir, 'witness.wtns');
    const witnessStats = await this.measureWitnessGeneration(
      wasmPath,
      inputPath,
      witnessPath,
      config.minRuns
    );

    // 6. Measure proof generation with hyperfine
    console.log(`    Measuring proof generation with hyperfine...`);
    const proveCommand = `cd "${patternBuildDir}" && npx snarkjs groth16 prove "${zkeyPath}" "${witnessPath}" proof.json public.json`;
    const proveResult = await runHyperfine(proveCommand, {
      warmup: config.warmupRuns,
      minRuns: config.minRuns,
      shell: 'default',
    });

    let proveStats: TimingStats;
    if (!proveResult.ok) {
      console.log(`    Warning: Hyperfine failed, using in-process measurement`);
      // Fallback to in-process measurement
      const { stats } = await measureAsync(
        () => prove(zkeyPath, witnessPath),
        config.minRuns
      );
      proveStats = stats;
    } else {
      proveStats = proveResult.value;
    }

    // 7. Measure verification (in-process, fast operation)
    console.log(`    Measuring verification (${config.minRuns} runs)...`);
    const { result: proveOutput } = await measureAsync(
      () => prove(zkeyPath, witnessPath),
      1
    );
    if (!proveOutput.ok) {
      return proveOutput;
    }

    const { stats: verifyStats } = await measureAsync(
      async () => verify(vkeyPath, proveOutput.value.publicSignals, proveOutput.value.proof),
      config.minRuns
    );

    // 8. Get peak memory (rough estimate via file sizes)
    const peakMemoryMB = await this.estimatePeakMemory(patternBuildDir);

    const metrics: CircomMetrics = {
      constraints,
      witnessGenMs: witnessStats,
      proveMs: proveStats,
      verifyMs: verifyStats,
      peakMemoryMB,
    };

    return ok(metrics);
  }

  supportsPattern(pattern: PatternDefinition): boolean {
    return pattern.availableInV1;
  }

  async cleanup(): Promise<void> {
    console.log('Cleaning up Circom v1 provider...');

    // Clean up worktree
    await cleanupV1Worktree();
    this.worktreePath = null;

    // Clean up build directory
    try {
      await fs.rm(this.buildDir, { recursive: true, force: true });
    } catch {
      // Ignore cleanup errors
    }

    console.log('  Circom v1 cleanup complete');
  }

  /**
   * Generate test input for a pattern at a specific length.
   */
  private generateTestInput(pattern: PatternDefinition, inputLengthBytes: number): Record<string, unknown> {
    // For v1 circuits, we need to generate circuit-specific inputs
    // This is a simplified version - real implementation would use the compiler
    const paddedInput = this.createPaddedInput(pattern, inputLengthBytes);

    return {
      msg: paddedInput.split('').map((c: string) => c.charCodeAt(0)),
    };
  }

  /**
   * Create padded input string for a pattern.
   */
  private createPaddedInput(pattern: PatternDefinition, targetLength: number): string {
    // Use sample test strings based on pattern
    const sampleInputs: Record<string, string> = {
      body_hash_regex: 'dkim-signature:v=1; a=rsa-sha256; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=',
      email_addr_regex: 'from:test@example.com\r\n',
      subject_all_regex: 'subject:Hello World\r\n',
      simple_regex: 'aaab',
    };

    let input = sampleInputs[pattern.circuitName] ?? 'test input';

    // Pad or truncate to target length
    if (input.length < targetLength) {
      // Pad with spaces
      input = input + ' '.repeat(targetLength - input.length);
    } else if (input.length > targetLength) {
      input = input.slice(0, targetLength);
    }

    return input;
  }

  /**
   * Measure witness generation timing.
   */
  private async measureWitnessGeneration(
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
      }
    }

    return calculateStats(times);
  }

  /**
   * Estimate peak memory from build artifacts.
   */
  private async estimatePeakMemory(buildDir: string): Promise<number> {
    try {
      const files = await fs.readdir(buildDir);
      let totalSize = 0;

      for (const file of files) {
        const filePath = path.join(buildDir, file);
        const stats = await fs.stat(filePath);
        if (stats.isFile()) {
          totalSize += stats.size;
        }
      }

      // Convert to MB and add rough estimate for runtime overhead
      return Math.round(totalSize / (1024 * 1024)) + 100;
    } catch {
      return 0;
    }
  }
}
