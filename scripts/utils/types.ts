/**
 * Type definitions for ZK Regex script utilities
 */

export interface CompilerOptions {
  decomposedRegexPath: string;
  outputFilePath: string;
  templateName: string;
  provingFramework: 'circom' | 'noir';
}

export interface ProcessResult {
  success: boolean;
  stdout?: string;
  stderr?: string;
  error?: Error;
}

export interface SampleData {
  pass: string[];
  fail: string[];
}

export interface CircuitInput {
  in_haystack: number[];
  match_start: number;
  match_length: number;
  curr_states: number[];
  next_states: number[];
  capture_group_start_indices?: number[];
  capture_group_ids?: number[][];
  capture_group_starts?: number[][];
}

export interface ScriptConfig {
  readonly projectRoot: string;
  readonly maxHaystackLen: number;
  readonly maxMatchLen: number;
  readonly saveInputsForSuccessfulFailCases: boolean;
  readonly directories: {
    readonly sampleHaystacks: string;
    readonly graphs: string;
    readonly circuits: string;
    readonly circuitInputs: string;
    readonly tempOutput: string;
  };
}

export interface UnexpectedSuccess {
  templateName: string;
  failCaseIndex: number;
  haystack: string;
}

export interface TestFunctionData {
  templateName: string;
  index: string;
  inputData: CircuitInput;
  numCaptureGroups: number;
}

export enum LogLevel {
  Debug = 0,
  Info = 1,
  Warn = 2,
  Error = 3,
}

export class ScriptError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'ScriptError';
  }
}