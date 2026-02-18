/**
 * Noir v2 (NFA-based) benchmark provider.
 *
 * This provider benchmarks the Noir backend, which uses sparse array
 * encoding for O(1) transition lookup (~14.5 gates per lookup).
 */

import * as path from 'path';
import * as fs from 'fs/promises';
import * as os from 'os';
import type {
  NoirMetrics,
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
import { runHyperfine } from '../utils/hyperfine.js';
import { measureAsync, calculateStats } from '../utils/timing.js';
import { runWithMemoryTracking, defaultMemoryStats } from '../utils/memory.js';

/** Parsed nargo info output */
interface NargoInfo {
  acirOpcodes: number;
  backendGates: number;
}

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
  return path.resolve(import.meta.dir, '..', '..', '..');
}

export class NoirV2Provider extends BaseBenchmarkProvider {
  readonly name = 'noir-v2';
  private buildDir: string;
  private projectRoot: string;
  private nargoVersion: string | null = null;
  private bbVersion: string | null = null;

  constructor() {
    super();
    this.buildDir = path.join(os.tmpdir(), 'zk-regex-noir-bench');
    this.projectRoot = getProjectRoot();
  }

  async setup(): Promise<Result<void>> {
    console.log('Setting up Noir v2 provider...');

    // 1. Verify nargo is installed
    const nargoResult = await execAsync('nargo --version');
    if (!nargoResult.ok) {
      return err(
        errors.missingBinary(
          'nargo',
          'curl -L https://raw.githubusercontent.com/noir-lang/noirup/refs/heads/main/install | bash && noirup'
        )
      );
    }
    this.nargoVersion = nargoResult.value;
    console.log(`  Nargo version: ${this.nargoVersion}`);

    // 2. Verify barretenberg (bb) is installed
    const bbResult = await execAsync('bb --version');
    if (!bbResult.ok) {
      return err(
        errors.missingBinary('bb', 'Installed with nargo via noirup')
      );
    }
    this.bbVersion = bbResult.value;
    console.log(`  Barretenberg version: ${this.bbVersion}`);

    // 3. Create build directory
    try {
      await fs.mkdir(this.buildDir, { recursive: true });
    } catch {
      // Directory might already exist
    }

    console.log('  Noir v2 provider setup complete');
    return ok(undefined);
  }

  async benchmarkPattern(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    config: BenchmarkConfig
  ): Promise<Result<BenchmarkMetrics>> {
    // Create a unique benchmark harness for this pattern/size combination
    const benchName = `${pattern.circuitName}_${inputLengthBytes}`;
    const benchDir = path.join(this.buildDir, benchName);

    // 1. Create benchmark harness project
    console.log(`    Creating benchmark harness for ${benchName}...`);
    const harnessResult = await this.createBenchmarkHarness(
      pattern,
      inputLengthBytes,
      benchDir
    );
    if (!harnessResult.ok) {
      return harnessResult;
    }

    // 2. Clean target/ for accurate compile timing
    const targetDir = path.join(benchDir, 'target');
    await fs.rm(targetDir, { recursive: true, force: true }).catch(() => {});

    // 3. Compile with nargo compile and measure memory
    console.log(`    Measuring compilation (${config.minRuns} runs)...`);
    const { timing: compileStats, memory: compileMemory } = await this.measureCompileWithMemory(benchDir, config.minRuns);

    // 4. Parse nargo info text output
    console.log(`    Getting circuit info...`);
    const infoResult = await this.getNargoInfo(benchDir);
    if (!infoResult.ok) {
      return infoResult;
    }
    const { acirOpcodes, backendGates } = infoResult.value;
    console.log(`    ACIR opcodes: ${acirOpcodes}, Backend gates: ${backendGates}`);

    // 5. Execute (witness generation) with nargo execute and measure memory
    console.log(`    Measuring witness generation (${config.minRuns} runs)...`);
    const { timing: witnessGenStats, memory: witnessGenMemory } = await this.measureWitnessGenWithMemory(benchDir, config.minRuns);

    // 6. Prove with bb prove_ultra_honk and measure memory
    console.log(`    Measuring proof generation (${config.minRuns} runs)...`);
    const { timing: proveStats, memory: proveMemory } = await this.measureProveWithMemory(benchDir, benchName, config);

    // 7. Verify with bb verify_ultra_honk and measure memory
    console.log(`    Measuring verification (${config.minRuns} runs)...`);
    const { timing: verifyStats, memory: verifyMemory } = await this.measureVerifyWithMemory(benchDir, benchName, config);

    // 8. Get proof size (bb v0.84.0+ stores proof in proof/proof)
    const proofFile = path.join(benchDir, 'target', 'proof', 'proof');
    let proofSizeBytes = 0;
    try {
      const stats = await fs.stat(proofFile);
      proofSizeBytes = stats.size;
    } catch {
      // Proof might not exist if proving failed
    }

    // Build memory by phase
    const memoryByPhase: PhaseMemory = {
      compile: compileMemory,
      witnessGen: witnessGenMemory,
      prove: proveMemory,
      verify: verifyMemory,
    };

    const metrics: NoirMetrics = {
      acirOpcodes,
      backendGates,
      gatesPerByte: inputLengthBytes > 0 ? backendGates / inputLengthBytes : 0,
      compileMs: compileStats,
      witnessGenMs: witnessGenStats,
      proveMs: proveStats,
      verifyMs: verifyStats,
      proofSizeBytes,
      memoryByPhase,
    };

    return ok(metrics);
  }

  supportsPattern(_pattern: PatternDefinition): boolean {
    // v2 Noir supports all patterns
    return true;
  }

  async cleanup(): Promise<void> {
    console.log('Cleaning up Noir v2 provider...');
    try {
      await fs.rm(this.buildDir, { recursive: true, force: true });
    } catch {
      // Ignore cleanup errors
    }
    console.log('  Noir v2 cleanup complete');
  }

  /**
   * Create a Noir benchmark harness project.
   *
   * Noir circuits in this repo are libraries, so we need to create
   * a binary project that imports and calls the regex_match function.
   */
  private async createBenchmarkHarness(
    pattern: PatternDefinition,
    inputLengthBytes: number,
    benchDir: string
  ): Promise<Result<void>> {
    // Create directory structure
    await fs.mkdir(path.join(benchDir, 'src'), { recursive: true });

    // Map circuit name to module name
    const moduleName = pattern.circuitName;

    // Create Nargo.toml that imports the main zkregex library
    const nargoToml = `[package]
name = "bench_${moduleName}"
type = "bin"
authors = [""]
compiler_version = ">=1.0.0"

[dependencies]
zkregex = { path = "${this.projectRoot}/noir" }
`;
    await fs.writeFile(path.join(benchDir, 'Nargo.toml'), nargoToml);

    // Read NUM_CAPTURE_GROUPS from the circuit file (same as gen-inputs.ts does)
    const numCaptureGroups = await this.getNumCaptureGroups(pattern.circuitName);

    // Create test input using pre-generated circuit inputs
    const inputResult = await this.loadOrGenerateInput(pattern, inputLengthBytes);
    if (!inputResult.ok) {
      return inputResult;
    }
    const input = inputResult.value;

    // Create main.nr that calls the regex_match function
    // The function signature varies based on NUM_CAPTURE_GROUPS (same logic as gen-inputs.ts)
    const mainNr = this.generateMainNr(moduleName, input, numCaptureGroups);
    await fs.writeFile(path.join(benchDir, 'src', 'main.nr'), mainNr);

    // Create Prover.toml with test inputs
    const proverToml = this.formatProverToml(input, numCaptureGroups);
    await fs.writeFile(path.join(benchDir, 'Prover.toml'), proverToml);

    return ok(undefined);
  }

  /**
   * Read NUM_CAPTURE_GROUPS from the circuit .nr file.
   */
  private async getNumCaptureGroups(circuitName: string): Promise<number> {
    const circuitPath = path.join(
      this.projectRoot,
      'noir',
      'src',
      'templates',
      'circuits',
      `${circuitName}.nr`
    );

    try {
      const content = await fs.readFile(circuitPath, 'utf-8');
      const match = content.match(/pub global NUM_CAPTURE_GROUPS: u32\s*=\s*(\d+);/);
      if (match) {
        return parseInt(match[1], 10);
      }
    } catch {
      // File not found or parse error
    }

    return 0;
  }

  /**
   * Generate main.nr content based on number of capture groups.
   * Mirrors the logic in noir/scripts/gen-inputs.ts generateTestFunction().
   */
  private generateMainNr(
    moduleName: string,
    input: NoirCircuitInput,
    numCaptureGroups: number
  ): string {
    const lines: string[] = [];
    lines.push(`use zkregex::templates::circuits::${moduleName}::regex_match;`);
    lines.push('');
    lines.push('fn main(');
    lines.push(`    in_haystack: [u8; ${input.in_haystack.length}],`);
    lines.push('    match_start: u32,');
    lines.push('    match_length: u32,');
    lines.push(`    current_states: [Field; ${input.curr_states.length}],`);
    lines.push(`    next_states: [Field; ${input.next_states.length}],`);

    // Add capture group parameters if needed
    if (numCaptureGroups > 0) {
      // Add capture_group_N_id for each capture group
      for (let i = 1; i <= numCaptureGroups; i++) {
        const cgIds = input.capture_group_ids?.[i - 1] ?? input.curr_states;
        lines.push(`    capture_group_${i}_id: [Field; ${cgIds.length}],`);
      }
      // Add capture_group_N_start for each capture group
      for (let i = 1; i <= numCaptureGroups; i++) {
        const cgStarts = input.capture_group_starts?.[i - 1] ?? input.curr_states;
        lines.push(`    capture_group_${i}_start: [Field; ${cgStarts.length}],`);
      }
      // Add capture_group_start_indices
      const cgStartIndices = input.capture_group_start_indices ?? [];
      lines.push(`    capture_group_start_indices: [Field; ${cgStartIndices.length}],`);
    }

    lines.push(') {');

    // Build the function call parameters
    const callParams = ['in_haystack', 'match_start', 'match_length', 'current_states', 'next_states'];
    if (numCaptureGroups > 0) {
      for (let i = 1; i <= numCaptureGroups; i++) {
        callParams.push(`capture_group_${i}_id`);
      }
      for (let i = 1; i <= numCaptureGroups; i++) {
        callParams.push(`capture_group_${i}_start`);
      }
      callParams.push('capture_group_start_indices');
    }

    const callParamsStr = callParams.join(', ');
    if (numCaptureGroups > 0) {
      lines.push(`    let _ = regex_match(${callParamsStr});`);
    } else {
      lines.push(`    regex_match(${callParamsStr});`);
    }

    lines.push('}');
    lines.push('');

    return lines.join('\n');
  }

  /**
   * Load pre-generated circuit input or generate a simple one.
   */
  private async loadOrGenerateInput(
    pattern: PatternDefinition,
    inputLengthBytes: number
  ): Promise<Result<NoirCircuitInput>> {
    // Try to load a pre-generated input
    const inputDir = path.join(
      this.projectRoot,
      'noir',
      'common',
      'sample_haystacks',
      'circuit_inputs'
    );

    // Pattern name without _regex suffix for input files
    const baseName = pattern.circuitName.replace('_regex', '');

    try {
      const files = await fs.readdir(inputDir);
      const matchingFile = files.find(
        (f) => f.startsWith(`${baseName}_pass_`) && f.endsWith('.json')
      );

      if (matchingFile) {
        const inputPath = path.join(inputDir, matchingFile);
        const content = await fs.readFile(inputPath, 'utf-8');
        const input = JSON.parse(content) as NoirCircuitInput;
        return ok(input);
      }
    } catch {
      // Fall through to generate input
    }

    // Generate a simple input if no pre-generated one exists
    return ok(this.generateSimpleInput(inputLengthBytes));
  }

  /**
   * Generate a simple test input for benchmarking.
   */
  private generateSimpleInput(inputLengthBytes: number): NoirCircuitInput {
    // Use 300 as the default max length (matching the Noir templates)
    const maxLen = Math.max(300, inputLengthBytes);

    // Create a simple 'b' input that matches a*b
    const haystack = new Array(maxLen).fill(0);
    haystack[0] = 98; // 'b'

    return {
      type: 'noir',
      in_haystack: haystack,
      match_start: 0,
      match_length: 1,
      curr_states: new Array(maxLen).fill(0),
      next_states: [4, ...new Array(maxLen - 1).fill(0)],
      capture_group_ids: [],
      capture_group_starts: [],
      capture_group_start_indices: [],
    };
  }

  /**
   * Format circuit input as TOML for Prover.toml.
   */
  private formatProverToml(input: NoirCircuitInput, numCaptureGroups: number): string {
    const lines: string[] = [];

    lines.push(`in_haystack = [${input.in_haystack.join(', ')}]`);
    lines.push(`match_start = ${input.match_start}`);
    lines.push(`match_length = ${input.match_length}`);
    lines.push(`current_states = [${input.curr_states.join(', ')}]`);
    lines.push(`next_states = [${input.next_states.join(', ')}]`);

    // Add capture group fields if needed
    if (numCaptureGroups > 0) {
      for (let i = 1; i <= numCaptureGroups; i++) {
        const cgIds = input.capture_group_ids?.[i - 1] ?? [];
        lines.push(`capture_group_${i}_id = [${cgIds.join(', ')}]`);
      }
      for (let i = 1; i <= numCaptureGroups; i++) {
        const cgStarts = input.capture_group_starts?.[i - 1] ?? [];
        lines.push(`capture_group_${i}_start = [${cgStarts.join(', ')}]`);
      }
      const cgStartIndices = input.capture_group_start_indices ?? [];
      lines.push(`capture_group_start_indices = [${cgStartIndices.join(', ')}]`);
    }

    return lines.join('\n') + '\n';
  }

  /**
   * Measure compile time with memory tracking.
   */
  private async measureCompileWithMemory(
    benchDir: string,
    runs: number
  ): Promise<{ timing: TimingStats; memory: MemoryStats }> {
    // First clean target for accurate timing
    await fs.rm(path.join(benchDir, 'target'), { recursive: true, force: true }).catch(() => {});

    const result = await runWithMemoryTracking('nargo compile --silence-warnings', {
      cwd: benchDir,
      runs,
    });

    if (result) {
      return { timing: result.timing, memory: result.memory };
    }

    // Fallback to legacy measurement without memory
    const timing = await this.measureCompileLegacy(benchDir, runs);
    return { timing, memory: defaultMemoryStats() };
  }

  /**
   * Legacy compile measurement without memory tracking.
   */
  private async measureCompileLegacy(benchDir: string, runs: number): Promise<TimingStats> {
    const times: number[] = [];

    for (let i = 0; i < runs; i++) {
      // Clean target between runs for accurate timing
      await fs.rm(path.join(benchDir, 'target'), { recursive: true, force: true }).catch(() => {});

      const start = performance.now();
      const result = await execAsync('nargo compile --silence-warnings', { cwd: benchDir });
      const end = performance.now();

      if (result.ok) {
        times.push(end - start);
      }
    }

    return calculateStats(times);
  }

  /**
   * Get circuit info using bb gates command.
   *
   * Uses bb gates to get both ACIR opcodes and circuit size (backend gates).
   * This is more reliable than parsing nargo info table output.
   */
  private async getNargoInfo(benchDir: string): Promise<Result<NargoInfo>> {
    // Get both ACIR opcodes and backend gates from bb gates
    return this.getBbGates(benchDir);
  }

  /**
   * Get circuit metrics using bb gates command.
   *
   * Returns both ACIR opcodes and circuit size (backend gates).
   * The JSON output format is:
   * {"functions": [{"acir_opcodes": N, "circuit_size": M}]}
   */
  private async getBbGates(benchDir: string): Promise<Result<NargoInfo>> {
    // Find the compiled bytecode
    const targetDir = path.join(benchDir, 'target');

    try {
      const files = await fs.readdir(targetDir);
      const jsonFile = files.find((f) => f.endsWith('.json') && !f.includes('vk'));

      if (!jsonFile) {
        return err(errors.fileNotFound(path.join(targetDir, '*.json')));
      }

      const bytecodeFile = path.join(targetDir, jsonFile);
      const result = await execAsync(
        `bb gates -b "${bytecodeFile}"`,
        { cwd: benchDir }
      );

      if (!result.ok) {
        return result;
      }

      // Parse JSON output from bb gates
      // Format: Scheme is: ultra_honk\n{"functions": [{"acir_opcodes": N, "circuit_size": M}]}
      const output = result.value;

      // Find the JSON part (starts with {)
      const jsonStart = output.indexOf('{');
      if (jsonStart === -1) {
        return ok({ acirOpcodes: 0, backendGates: 0 });
      }

      const jsonStr = output.slice(jsonStart);
      const parsed = JSON.parse(jsonStr);

      if (parsed.functions && parsed.functions.length > 0) {
        const fn = parsed.functions[0];
        return ok({
          acirOpcodes: fn.acir_opcodes ?? 0,
          backendGates: fn.circuit_size ?? 0,
        });
      }

      return ok({ acirOpcodes: 0, backendGates: 0 });
    } catch {
      return ok({ acirOpcodes: 0, backendGates: 0 });
    }
  }

  /**
   * Measure witness generation (execute) time with memory tracking.
   */
  private async measureWitnessGenWithMemory(
    benchDir: string,
    runs: number
  ): Promise<{ timing: TimingStats; memory: MemoryStats }> {
    const result = await runWithMemoryTracking('nargo execute --silence-warnings', {
      cwd: benchDir,
      runs,
    });

    if (result) {
      return { timing: result.timing, memory: result.memory };
    }

    // Fallback to legacy measurement without memory
    const timing = await this.measureWitnessGenLegacy(benchDir, runs);
    return { timing, memory: defaultMemoryStats() };
  }

  /**
   * Legacy witness generation measurement without memory tracking.
   */
  private async measureWitnessGenLegacy(benchDir: string, runs: number): Promise<TimingStats> {
    const times: number[] = [];

    for (let i = 0; i < runs; i++) {
      const start = performance.now();
      const result = await execAsync('nargo execute --silence-warnings', { cwd: benchDir });
      const end = performance.now();

      if (result.ok) {
        times.push(end - start);
      }
    }

    return calculateStats(times);
  }

  /**
   * Measure proof generation time with memory tracking.
   */
  private async measureProveWithMemory(
    benchDir: string,
    benchName: string,
    config: BenchmarkConfig
  ): Promise<{ timing: TimingStats; memory: MemoryStats }> {
    const targetDir = path.join(benchDir, 'target');

    // Find the compiled bytecode and witness
    try {
      const files = await fs.readdir(targetDir);
      const jsonFile = files.find((f) => f.endsWith('.json') && !f.includes('vk'));
      const witnessFile = files.find((f) => f.endsWith('.gz'));

      if (!jsonFile || !witnessFile) {
        console.log(`    Warning: Bytecode or witness not found`);
        return { timing: calculateStats([]), memory: defaultMemoryStats() };
      }

      const bytecodeFile = path.join(targetDir, jsonFile);
      const witnessPath = path.join(targetDir, witnessFile);
      // bb v0.84.0+ uses directories for output - creates vk/vk, proof/proof, proof/public_inputs
      const proofDir = path.join(targetDir, 'proof');
      const vkDir = path.join(targetDir, 'vk');

      // Create output directories
      await fs.mkdir(proofDir, { recursive: true });
      await fs.mkdir(vkDir, { recursive: true });

      // Generate VK first (needed for verification)
      // bb v0.84.0+ API: bb write_vk -s ultra_honk -o <dir> creates <dir>/vk
      await execAsync(
        `bb write_vk -s ultra_honk -b "${bytecodeFile}" -o "${vkDir}"`,
        { cwd: benchDir }
      );

      // Use memory tracking for prove measurement
      // bb v0.84.0+ API: bb prove -s ultra_honk -o <dir> creates <dir>/proof and <dir>/public_inputs
      const proveCommand = `bb prove -s ultra_honk -b "${bytecodeFile}" -w "${witnessPath}" -o "${proofDir}"`;
      const result = await runWithMemoryTracking(proveCommand, {
        cwd: benchDir,
        runs: config.minRuns,
      });

      if (result) {
        return { timing: result.timing, memory: result.memory };
      }

      // Fallback to hyperfine or in-process measurement
      console.log(`    Warning: Memory tracking failed, using hyperfine fallback`);
      const hyperfineResult = await runHyperfine(proveCommand, {
        warmup: config.warmupRuns,
        minRuns: config.minRuns,
        shell: 'default',
        cwd: benchDir,
      });

      if (hyperfineResult.ok) {
        return { timing: hyperfineResult.value, memory: defaultMemoryStats() };
      }

      // Final fallback to in-process measurement
      const { stats } = await measureAsync(
        async () => {
          await execAsync(proveCommand, { cwd: benchDir });
        },
        config.minRuns
      );
      return { timing: stats, memory: defaultMemoryStats() };
    } catch (error) {
      console.log(`    Warning: Prove measurement failed: ${error}`);
      return { timing: calculateStats([]), memory: defaultMemoryStats() };
    }
  }

  /**
   * Measure verification time with memory tracking.
   */
  private async measureVerifyWithMemory(
    benchDir: string,
    benchName: string,
    config: BenchmarkConfig
  ): Promise<{ timing: TimingStats; memory: MemoryStats }> {
    const targetDir = path.join(benchDir, 'target');
    // bb v0.84.0+ uses directories: vk/vk, proof/proof, proof/public_inputs
    const proofFile = path.join(targetDir, 'proof', 'proof');
    const publicInputsFile = path.join(targetDir, 'proof', 'public_inputs');
    const vkFile = path.join(targetDir, 'vk', 'vk');

    // Check if proof, public_inputs, and vk exist
    try {
      await fs.access(proofFile);
      await fs.access(publicInputsFile);
      await fs.access(vkFile);
    } catch {
      console.log(`    Warning: Proof, public_inputs, or VK not found`);
      return { timing: calculateStats([]), memory: defaultMemoryStats() };
    }

    // bb v0.84.0+ API: bb verify -s ultra_honk -p <proof> -k <vk> -i <public_inputs>
    const verifyCommand = `bb verify -s ultra_honk -p "${proofFile}" -k "${vkFile}" -i "${publicInputsFile}"`;
    const result = await runWithMemoryTracking(verifyCommand, {
      cwd: benchDir,
      runs: config.minRuns,
    });

    if (result) {
      return { timing: result.timing, memory: result.memory };
    }

    // Fallback to hyperfine or in-process measurement
    console.log(`    Warning: Memory tracking failed, using hyperfine fallback`);
    const hyperfineResult = await runHyperfine(verifyCommand, {
      warmup: config.warmupRuns,
      minRuns: config.minRuns,
      shell: 'default',
      cwd: benchDir,
    });

    if (hyperfineResult.ok) {
      return { timing: hyperfineResult.value, memory: defaultMemoryStats() };
    }

    // Final fallback to in-process measurement
    const { stats } = await measureAsync(
      async () => {
        await execAsync(verifyCommand, { cwd: benchDir });
      },
      config.minRuns
    );
    return { timing: stats, memory: defaultMemoryStats() };
  }
}

/** Structure of Noir circuit input */
interface NoirCircuitInput {
  type: string;
  in_haystack: number[];
  match_start: number;
  match_length: number;
  curr_states: number[];
  next_states: number[];
  /** Array of arrays - one per capture group, each containing field values */
  capture_group_ids: number[][];
  /** Array of arrays - one per capture group, each containing start positions */
  capture_group_starts: number[][];
  capture_group_start_indices: number[];
}
