/**
 * Circom DFA benchmark provider.
 *
 * This provider creates a git worktree of the main branch to benchmark
 * the DFA-based compiler against the current NFA implementation.
 */

import * as path from 'path';
import * as fs from 'fs/promises';
import * as os from 'os';
import type {
  CircomMetrics,
  PatternDefinition,
  BenchmarkConfig,
  TimingStats,
  PhaseMemory,
  MemoryStats,
  ToolVersions,
} from '../types.js';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import { BaseBenchmarkProvider, type BenchmarkMetrics } from './base.js';
import { execAsync, wrapCommandWithNvm } from '../utils/exec.js';
import {
  setupDfaWorktree,
  cleanupDfaWorktree,
  getDfaWorktreePath,
  getDfaCircuitPath,
} from '../utils/worktree.js';
import { ensurePtauFile, getMaxConstraints } from '../utils/ptau.js';
import { getConstraintCount, groth16Setup, prove, verify, exportVkey, measureWitnessGeneration } from '../utils/snarkjs.js';
import { getCircomToolVersions } from '../utils/hardware.js';
import { runHyperfine } from '../utils/hyperfine.js';
import { measureAsync } from '../utils/timing.js';
import { runWithMemoryTracking, defaultMemoryStats } from '../utils/memory.js';
import { generateScaledInput } from '../utils/input-scaling.js';

const BENCHMARK_CONFIG_PATH = path.join(import.meta.dir, '..', '..', 'config', 'benchmark.json');

export class CircomDFAProvider extends BaseBenchmarkProvider {
  readonly name = 'circom-dfa';
  private worktreePath: string | null = null;
  private ptauPath: string | null = null;
  private buildDir: string;
  private commitHash: string = 'unknown';

  constructor() {
    super();
    this.buildDir = path.join(os.tmpdir(), 'zk-regex-dfa-build');
  }

  getCommitHash(): string {
    return this.commitHash;
  }

  getToolVersions(): ToolVersions {
    return getCircomToolVersions();
  }

  async setup(): Promise<Result<void>> {
    console.log('Setting up Circom DFA provider...');

    // 1. Read commit hash from config
    try {
      const content = await fs.readFile(BENCHMARK_CONFIG_PATH, 'utf-8');
      const config = JSON.parse(content);
      this.commitHash = config?.providers?.['circom-dfa']?.commitHash ?? 'unknown';
    } catch {
      this.commitHash = 'unknown';
    }

    // 2. Set up worktree from main branch
    const worktreeResult = await setupDfaWorktree();
    if (!worktreeResult.ok) {
      return err(worktreeResult.error);
    }
    this.worktreePath = worktreeResult.value;
    console.log(`  Worktree ready at: ${this.worktreePath}`);

    // 3. Download/cache Powers of Tau
    const ptauResult = await ensurePtauFile();
    if (!ptauResult.ok) {
      return err(ptauResult.error);
    }
    this.ptauPath = ptauResult.value;
    console.log(`  Powers of Tau ready: ${this.ptauPath}`);

    // 4. Create build directory
    try {
      await fs.mkdir(this.buildDir, { recursive: true });
    } catch {
      // Directory might already exist
    }

    console.log('  Circom DFA provider setup complete');
    return ok(undefined);
  }

  async benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>> {
    if (!this.supportsPattern(pattern)) {
      return err(errors.compilationFailed(pattern.name, 'Pattern not available in DFA'));
    }

    if (!this.worktreePath || !this.ptauPath) {
      return err(errors.compilationFailed(pattern.name, 'Provider not initialized'));
    }

    const circuitPath = getDfaCircuitPath(pattern.circuitName);

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
    // The DFA templates don't have a main component, just a template definition
    const templateName = pattern.circuitName
      .split('_')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join('');

    const wrapperName = `${pattern.circuitName}_wrapper`;
    const wrapperPath = path.join(patternBuildDir, `${wrapperName}.circom`);

    // DFA circuits use msg_bytes parameter and msg input
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

    // 5. Measure compilation with memory tracking
    console.log(`    Measuring circuit compilation (${config.minRuns} runs)...`);
    const compileCommand = `circom "${wrapperPath}" --r1cs --wasm -l "${nodeModulesDir}" -o "${patternBuildDir}"`;
    const compileMeasurement = await runWithMemoryTracking(compileCommand, {
      cwd: this.worktreePath,
      runs: config.minRuns,
    });
    const compileMemory = compileMeasurement?.memory ?? defaultMemoryStats();

    // 6. Measure witness generation with memory tracking
    console.log(`    Measuring witness generation (${config.minRuns} runs)...`);
    const witnessPath = path.join(patternBuildDir, 'witness.wtns');
    const witnessCommand = wrapCommandWithNvm(
      `npx snarkjs wtns calculate "${wasmPath}" "${inputPath}" "${witnessPath}"`,
      { bashWrap: true }
    );
    const witnessResult = await runWithMemoryTracking(witnessCommand, {
      cwd: patternBuildDir,
      runs: config.minRuns,
    });
    let witnessStats: TimingStats;
    let witnessMemory: MemoryStats;
    if (witnessResult) {
      witnessStats = witnessResult.timing;
      witnessMemory = witnessResult.memory;
    } else {
      // Fallback to legacy measurement without memory
      witnessStats = await measureWitnessGeneration(wasmPath, inputPath, witnessPath, config.minRuns);
      witnessMemory = defaultMemoryStats();
    }

    // 7. Measure proof generation with memory tracking
    console.log(`    Measuring proof generation (${config.minRuns} runs)...`);
    const proveCommand = wrapCommandWithNvm(
      `npx snarkjs groth16 prove "${zkeyPath}" "${witnessPath}" proof.json public.json`,
      { bashWrap: true }
    );
    const proveResult = await runWithMemoryTracking(proveCommand, {
      cwd: patternBuildDir,
      runs: config.minRuns,
    });
    let proveStats: TimingStats;
    let proveMemory: MemoryStats;
    if (proveResult) {
      proveStats = proveResult.timing;
      proveMemory = proveResult.memory;
    } else {
      // Fallback to hyperfine or in-process measurement
      console.log(`    Memory tracking failed, using hyperfine fallback`);
      const hyperfineResult = await runHyperfine(`cd "${patternBuildDir}" && ${proveCommand}`, {
        warmup: config.warmupRuns,
        minRuns: config.minRuns,
        shell: 'default',
      });
      if (hyperfineResult.ok) {
        proveStats = hyperfineResult.value;
      } else {
        const { stats } = await measureAsync(() => prove(zkeyPath, witnessPath), config.minRuns, config.warmupRuns);
        proveStats = stats;
      }
      proveMemory = defaultMemoryStats();
    }

    // 8. Measure verification with memory tracking
    console.log(`    Measuring verification (${config.minRuns} runs)...`);
    // First generate a proof to get public signals for verification
    const { result: proveOutput } = await measureAsync(() => prove(zkeyPath, witnessPath), 1);
    if (!proveOutput.ok) {
      return proveOutput;
    }

    // Write temp files for verification command
    const tempProofPath = path.join(patternBuildDir, 'temp_proof.json');
    const tempPublicPath = path.join(patternBuildDir, 'temp_public.json');
    await fs.writeFile(tempProofPath, JSON.stringify(proveOutput.value.proof, null, 2));
    await fs.writeFile(tempPublicPath, JSON.stringify(proveOutput.value.publicSignals, null, 2));

    const verifyCommand = wrapCommandWithNvm(
      `npx snarkjs groth16 verify "${vkeyPath}" "${tempPublicPath}" "${tempProofPath}"`,
      { bashWrap: true }
    );
    const verifyResult = await runWithMemoryTracking(verifyCommand, {
      cwd: patternBuildDir,
      runs: config.minRuns,
    });
    let verifyStats: TimingStats;
    let verifyMemory: MemoryStats;
    if (verifyResult) {
      verifyStats = verifyResult.timing;
      verifyMemory = verifyResult.memory;
    } else {
      // Fallback to in-process measurement
      const { stats } = await measureAsync(
        async () => verify(vkeyPath, proveOutput.value.publicSignals, proveOutput.value.proof),
        config.minRuns,
        config.warmupRuns
      );
      verifyStats = stats;
      verifyMemory = defaultMemoryStats();
    }

    // Clean up temp files
    await fs.unlink(tempProofPath).catch(() => {});
    await fs.unlink(tempPublicPath).catch(() => {});

    // Build memory by phase
    const memoryByPhase: PhaseMemory = {
      compile: compileMemory,
      witnessGen: witnessMemory,
      prove: proveMemory,
      verify: verifyMemory,
    };

    const metrics: CircomMetrics = {
      constraints,
      witnessGenMs: witnessStats,
      proveMs: proveStats,
      verifyMs: verifyStats,
      memoryByPhase,
    };

    return ok(metrics);
  }

  supportsPattern(pattern: PatternDefinition): boolean {
    return pattern.availableInV1;
  }

  async cleanup(): Promise<void> {
    console.log('Cleaning up Circom DFA provider...');

    // Clean up worktree
    await cleanupDfaWorktree();
    this.worktreePath = null;

    // Clean up build directory
    try {
      await fs.rm(this.buildDir, { recursive: true, force: true });
    } catch {
      // Ignore cleanup errors
    }

    console.log('  Circom DFA cleanup complete');
  }

  /**
   * Generate test input for a pattern at a specific length.
   */
  private generateTestInput(pattern: PatternDefinition, inputLengthBytes: number): Record<string, unknown> {
    // For DFA circuits, we need to generate circuit-specific inputs
    // This is a simplified version - real implementation would use the compiler
    const paddedInput = this.createPaddedInput(pattern, inputLengthBytes);

    return {
      msg: paddedInput.split('').map((c: string) => c.charCodeAt(0)),
    };
  }

  /**
   * Create input string for a pattern at target length.
   *
   * Uses scaled inputs that fill the target length with regex-matching
   * content when the pattern has scaling config.
   */
  private createPaddedInput(pattern: PatternDefinition, targetLength: number): string {
    if (pattern.inputTemplate && pattern.scalingStrategy) {
      return generateScaledInput(
        {
          strategy: pattern.scalingStrategy,
          inputTemplate: pattern.inputTemplate,
          extendChar: pattern.extendChar,
          extendPosition: pattern.extendPosition,
        },
        targetLength
      );
    }

    // Fallback for patterns without scaling config
    let input = pattern.sampleInput ?? 'test input';

    if (input.length < targetLength) {
      input = input + ' '.repeat(targetLength - input.length);
    } else if (input.length > targetLength) {
      input = input.slice(0, targetLength);
    }

    return input;
  }

}
