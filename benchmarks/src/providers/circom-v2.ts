/**
 * Circom v2 (NFA-based) benchmark provider.
 *
 * This provider benchmarks the current v2 implementation using
 * the NFA-based compiler with modular helper templates.
 */

import * as path from 'path';
import * as fs from 'fs/promises';
import * as os from 'os';
import type {
  CircomV2Metrics,
  PatternDefinition,
  BenchmarkConfig,
  TimingStats,
  PhaseMemory,
  MemoryStats,
} from '../types.js';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import { BaseBenchmarkProvider, type BenchmarkMetrics } from './base.js';
import { getAbortSignal } from '../utils/abort.js';
import { ensurePtauFile, getMaxConstraints } from '../utils/ptau.js';
import { getConstraintCount, groth16Setup, generateWitness, prove, verify, exportVkey } from '../utils/snarkjs.js';
import { runHyperfine } from '../utils/hyperfine.js';
import { measureAsync, calculateStats } from '../utils/timing.js';
import { runWithMemoryTracking, defaultMemoryStats } from '../utils/memory.js';
import { generateScaledInput } from '../utils/input-scaling.js';

// Import compiler for input generation
import { genCircuitInputs, ProvingFramework } from '../../../compiler/pkg/zk_regex_compiler.js';

/** Structure of the NFA graph JSON file */
interface NFAGraph {
  regex: string;
  nodes: Array<{
    state_id: number;
    byte_transitions: Record<string, number[]>;
    capture_groups: Record<string, unknown[]>;
  }>;
  start_states: number[];
  accept_states: number[];
  num_capture_groups: number;
}

/**
 * Execute a shell command and return result.
 */
async function execAsync(
  command: string,
  options: { cwd?: string } = {}
): Promise<Result<string>> {
  try {
    const proc = Bun.spawn(['sh', '-c', command], {
      cwd: options.cwd,
      stdout: 'pipe',
      stderr: 'pipe',
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
 * Get the project root directory.
 */
function getProjectRoot(): string {
  // benchmarks/src/providers -> go up 3 levels to reach project root
  return path.resolve(import.meta.dir, '..', '..', '..');
}

export class CircomV2Provider extends BaseBenchmarkProvider {
  readonly name = 'circom-v2';
  private ptauPath: string | null = null;
  private buildDir: string;
  private projectRoot: string;

  constructor() {
    super();
    this.buildDir = path.join(os.tmpdir(), 'zk-regex-v2-build');
    this.projectRoot = getProjectRoot();
  }

  async setup(): Promise<Result<void>> {
    console.log('Setting up Circom v2 provider...');

    // 1. Verify circom is installed and check version
    const versionResult = await execAsync('circom --version');
    if (!versionResult.ok) {
      return err(errors.missingBinary('circom', 'cargo install circom'));
    }
    console.log(`  Circom version: ${versionResult.value}`);

    // Check version is >= 2.1.9
    const version = versionResult.value.match(/circom compiler (\d+\.\d+\.\d+)/)?.[1];
    if (version) {
      const [major, minor, patch] = version.split('.').map(Number);
      if (major < 2 || (major === 2 && minor < 1) || (major === 2 && minor === 1 && patch < 9)) {
        return err(
          errors.missingBinary(
            'circom',
            `Circom >= 2.1.9 required (found ${version}). Install with: cargo install circom`
          )
        );
      }
    }

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

    console.log('  Circom v2 provider setup complete');
    return ok(undefined);
  }

  async benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>> {
    if (!this.ptauPath) {
      return err(errors.compilationFailed(pattern.name, 'Provider not initialized'));
    }

    // Get circuit path in v2 layout
    const circuitDir = path.join(this.projectRoot, 'circom', 'circuits', 'common');
    const circuitPath = path.join(circuitDir, `${pattern.circuitName}.circom`);
    const graphPath = path.join(circuitDir, `${pattern.circuitName.replace('_regex', '')}_graph.json`);

    // Check if circuit exists
    try {
      await fs.access(circuitPath);
    } catch {
      return err(errors.fileNotFound(circuitPath));
    }

    // 1. Extract NFA graph info (states, transitions) and load graph JSON for input generation
    let states = 0;
    let transitions = 0;
    let graphJson: string | null = null;
    try {
      graphJson = await fs.readFile(graphPath, 'utf-8');
      const graph: NFAGraph = JSON.parse(graphJson);
      states = graph.nodes.length;
      transitions = graph.nodes.reduce((sum, node) => {
        return sum + Object.values(node.byte_transitions).reduce(
          (nodeSum, targets) => nodeSum + targets.length,
          0
        );
      }, 0);
      console.log(`    NFA: ${states} states, ${transitions} transitions`);
    } catch {
      // Graph file is required for input generation
      return err(errors.fileNotFound(graphPath));
    }

    // Create pattern-specific build directory
    const patternBuildDir = path.join(this.buildDir, `${pattern.circuitName}_${inputLengthBytes}`);
    await fs.mkdir(patternBuildDir, { recursive: true });

    // 2. Create wrapper circuit that instantiates the template
    const wrapperName = `bench_${pattern.circuitName}`;
    const wrapperPath = path.join(patternBuildDir, `${wrapperName}.circom`);

    // Get the template name (capitalize first letter of each word)
    const templateName = pattern.circuitName
      .split('_')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join('');

    // Use consistent MAX sizes for benchmarking (matching Noir templates: 300)
    // Note: maxMatchBytes must be strictly less than maxHaystackBytes (per SelectSubArray assert)
    const maxHaystackBytes = Math.max(300, inputLengthBytes) + 1;
    const maxMatchBytes = maxHaystackBytes - 1;

    const wrapperCode = `pragma circom 2.1.5;

include "common/${pattern.circuitName}.circom";

component main {public [inHaystack]} = ${templateName}(${maxHaystackBytes}, ${maxMatchBytes});
`;
    await fs.writeFile(wrapperPath, wrapperCode);

    // 3. Compile wrapper circuit
    console.log(`    Compiling ${pattern.circuitName}...`);
    const r1csPath = path.join(patternBuildDir, `${wrapperName}.r1cs`);
    const wasmDir = path.join(patternBuildDir, `${wrapperName}_js`);
    const wasmPath = path.join(wasmDir, `${wrapperName}.wasm`);

    // Include the circom/circuits directory and node_modules for imports
    const includeDir = path.join(this.projectRoot, 'circom', 'circuits');
    const nodeModulesDir = path.join(this.projectRoot, 'node_modules');
    const compileResult = await execAsync(
      `circom "${wrapperPath}" --r1cs --wasm -l "${includeDir}" -l "${nodeModulesDir}" -o "${patternBuildDir}"`,
      { cwd: this.projectRoot }
    );
    if (!compileResult.ok) {
      return compileResult;
    }

    // 3. Get constraint count
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

    // 4. Generate test input using compiler
    const inputPath = path.join(patternBuildDir, 'input.json');
    const testInput = this.generateTestInput(
      pattern,
      inputLengthBytes,
      graphJson,
      maxHaystackBytes,
      maxMatchBytes
    );
    await fs.writeFile(inputPath, JSON.stringify(testInput, null, 2));

    // 5. Setup Groth16 (zkey)
    console.log(`    Setting up Groth16...`);
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

    // 6. Measure compilation with memory tracking
    console.log(`    Measuring circuit compilation (${config.minRuns} runs)...`);
    const compileCommand = `circom "${wrapperPath}" --r1cs --wasm -l "${includeDir}" -l "${nodeModulesDir}" -o "${patternBuildDir}"`;
    const compileMeasurement = await runWithMemoryTracking(compileCommand, {
      cwd: this.projectRoot,
      runs: config.minRuns,
    });
    const compileMemory = compileMeasurement?.memory ?? defaultMemoryStats();

    // 7. Measure witness generation with memory tracking
    console.log(`    Measuring witness generation (${config.minRuns} runs)...`);
    const witnessPath = path.join(patternBuildDir, 'witness.wtns');
    const witnessCommand = this.getNvmWrappedCommand(
      `npx snarkjs wtns calculate "${wasmPath}" "${inputPath}" "${witnessPath}"`
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
      witnessStats = await this.measureWitnessGeneration(wasmPath, inputPath, witnessPath, config.minRuns);
      witnessMemory = defaultMemoryStats();
    }

    // 8. Measure proof generation with memory tracking
    console.log(`    Measuring proof generation (${config.minRuns} runs)...`);
    const proveCommand = this.getNvmWrappedCommand(
      `npx snarkjs groth16 prove "${zkeyPath}" "${witnessPath}" proof.json public.json`
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
        const { stats } = await measureAsync(() => prove(zkeyPath, witnessPath), config.minRuns);
        proveStats = stats;
      }
      proveMemory = defaultMemoryStats();
    }

    // 9. Measure verification with memory tracking
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

    const verifyCommand = this.getNvmWrappedCommand(
      `npx snarkjs groth16 verify "${vkeyPath}" "${tempPublicPath}" "${tempProofPath}"`
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
        config.minRuns
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

    const metrics: CircomV2Metrics = {
      constraints,
      states,
      transitions,
      witnessGenMs: witnessStats,
      proveMs: proveStats,
      verifyMs: verifyStats,
      memoryByPhase,
    };

    return ok(metrics);
  }

  supportsPattern(_pattern: PatternDefinition): boolean {
    // v2 supports all patterns
    return true;
  }

  async cleanup(): Promise<void> {
    console.log('Cleaning up Circom v2 provider...');
    try {
      await fs.rm(this.buildDir, { recursive: true, force: true });
    } catch {
      // Ignore cleanup errors
    }
    console.log('  Circom v2 cleanup complete');
  }

  /**
   * Generate test input for a pattern using the compiler.
   *
   * Uses genCircuitInputs() from the compiler to generate proper
   * NFA traversal inputs for the circuit. When the pattern has scaling
   * config, generates content that fills inputLengthBytes with
   * regex-matching text.
   */
  private generateTestInput(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    graphJson: string,
    maxHaystackBytes: number,
    maxMatchBytes: number
  ): Record<string, unknown> {
    let haystack: string;

    if (pattern.inputTemplate && pattern.scalingStrategy) {
      // Use scaled input that fills the target length with matching content
      haystack = generateScaledInput(
        {
          strategy: pattern.scalingStrategy,
          inputTemplate: pattern.inputTemplate,
          extendChar: pattern.extendChar,
          extendPosition: pattern.extendPosition,
        },
        inputLengthBytes
      );
    } else {
      // Fallback to hardcoded samples for patterns without scaling config
      const sampleInputs: Record<string, string> = {
        body_hash_regex: '\r\ndkim-signature:v=1; a=rsa-sha256; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=',
        email_addr_regex: '\r\nto:test@example.com\r\n',
        subject_all_regex: '\r\nsubject:Hello World\r\n',
        simple_regex: 'b',
      };
      haystack = sampleInputs[pattern.circuitName] ?? pattern.sampleInput ?? 'b';
    }

    // Use compiler to generate circuit inputs
    const inputsJson = genCircuitInputs(
      graphJson,
      haystack,
      maxHaystackBytes,
      maxMatchBytes,
      ProvingFramework.Circom
    );

    const inputs = JSON.parse(inputsJson);
    const graph = JSON.parse(graphJson);

    // Only add capture group inputs if the circuit has capture groups
    const numCaptureGroups = graph.num_capture_groups ?? 0;

    if (numCaptureGroups > 0 && inputs.captureGroupIds && inputs.captureGroupStarts) {
      // The compiler returns captureGroupIds and captureGroupStarts as arrays of arrays
      // The circuit expects captureGroup1Id, captureGroup1Start, etc.
      inputs.captureGroup1Id = inputs.captureGroupIds[0] ?? new Array(maxMatchBytes).fill(0);
      inputs.captureGroup1Start = inputs.captureGroupStarts[0] ?? new Array(maxMatchBytes).fill(0);
    }

    // Always remove the compiler's array format - circuit uses individual signals
    delete inputs.captureGroupIds;
    delete inputs.captureGroupStarts;

    // Remove type metadata field if present
    delete inputs.type;

    return inputs;
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
      } else if (i === 0) {
        // Log first failure to help debug - use formatError for proper formatting
        console.log(`      Warning: Witness generation failed`);
        if (result.error.kind === 'compilation_failed') {
          console.log(`        ${result.error.stderr.split('\n')[0]}`);
        }
      }
    }

    if (times.length === 0) {
      // Return placeholder stats if all runs failed
      return { mean: 0, stddev: 0, min: 0, max: 0, runs: 0, coefficientOfVariation: 0 };
    }

    return calculateStats(times);
  }

  /**
   * Get a command wrapped with nvm sourcing for npx availability.
   * Filters out Bun's node shim paths to avoid conflicts.
   */
  private getNvmWrappedCommand(command: string): string {
    return `bash -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; ${command.replace(/'/g, "'\\''")} '`;
  }
}
