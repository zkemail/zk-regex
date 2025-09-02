#!/usr/bin/env node

/**
 * TypeScript version of gen_inputs.py
 * Complex circuit input generation and Noir test scaffolding
 */

import * as path from 'path';
import { fileURLToPath } from 'url';
import {
  logger,
  ScriptError,
  SampleData,
  CircuitInput,
  UnexpectedSuccess,
  ScriptConfig,
  ensureDirectory,
  readJsonFile,
  writeTextFile,
  readTextFile,
  fileExists,
  removeFile,
  executeCargo,
  isCommandAvailable,
  globFiles,
} from '../../scripts/utils/index.js';

// Get current file directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const SCRIPT_DIR = __dirname;
// Calculate project root (accounting for dist directory if compiled)
const PROJECT_ROOT = __dirname.includes('/dist/') 
  ? path.resolve(SCRIPT_DIR, '..', '..', '..', '..') 
  : path.resolve(SCRIPT_DIR, '..', '..');

const DEFAULT_MAX_HAYSTACK_LEN = 300;
const DEFAULT_MAX_MATCH_LEN = 300;
const SAVE_INPUTS_FOR_SUCCESSFUL_FAIL_CASES = false;

// Create script configuration
const config: ScriptConfig = {
  projectRoot: PROJECT_ROOT,
  maxHaystackLen: DEFAULT_MAX_HAYSTACK_LEN,
  maxMatchLen: DEFAULT_MAX_MATCH_LEN,
  saveInputsForSuccessfulFailCases: SAVE_INPUTS_FOR_SUCCESSFUL_FAIL_CASES,
  directories: {
    sampleHaystacks: path.join(PROJECT_ROOT, 'noir', 'common', 'sample_haystacks'),
    graphs: path.join(PROJECT_ROOT, 'noir', 'src', 'templates', 'graphs'),
    circuits: path.join(PROJECT_ROOT, 'noir', 'src', 'templates', 'circuits'),
    circuitInputs: path.join(PROJECT_ROOT, 'noir', 'common', 'sample_haystacks', 'circuit_inputs'),
    tempOutput: path.join(PROJECT_ROOT, 'noir', 'src', 'templates', 'temp_gen'),
  },
};

/**
 * Checks if jq is installed on the system
 */
function checkJq(): boolean {
  return isCommandAvailable('jq');
}

/**
 * Generate circuit inputs for pass and fail cases
 */
async function generateCircuitInputs(): Promise<UnexpectedSuccess[]> {
  logger.info('Phase 1: Generating circuit inputs...');
  const unexpectedSuccesses: UnexpectedSuccess[] = [];

  // Get all sample JSON files
  const sampleJsonFiles = await globFiles(config.directories.sampleHaystacks, '*.json');

  for (const sampleJsonFile of sampleJsonFiles) {
    if (!(await fileExists(sampleJsonFile))) {
      logger.info(`Skipping non-file: ${sampleJsonFile}`);
      continue;
    }

    const templateName = path.parse(sampleJsonFile).name;
    logger.info(`Processing sample haystacks for: ${templateName}`);

    const graphPath = path.join(config.directories.graphs, `${templateName}_graph.json`);
    if (!(await fileExists(graphPath))) {
      logger.error(`  Error: Graph file not found at ${graphPath}. Skipping ${templateName}.`);
      continue;
    }

    let sampleData: SampleData;
    try {
      sampleData = await readJsonFile<SampleData>(sampleJsonFile);
    } catch (error) {
      logger.error(`  Error: Could not parse JSON from ${sampleJsonFile}: ${error}. Skipping.`);
      continue;
    }

    // Process "pass" cases
    const passHaystacks = sampleData.pass || [];
    if (passHaystacks.length > 0) {
      for (const [index, haystack] of passHaystacks.entries()) {
        if (!haystack) continue; // Skip empty haystacks

        logger.info(`  Generating 'pass' input ${index} for ${templateName}...`);
        const outputCircuitInputJson = path.join(
          config.directories.circuitInputs,
          `${templateName}_pass_${index}.json`
        );

        const result = executeCargo('run', [
          '--quiet',
          '--bin', 'zk-regex',
          'generate-circuit-input',
          '--graph-path', graphPath,
          '--input', haystack,
          '--max-haystack-len', config.maxHaystackLen.toString(),
          '--max-match-len', config.maxMatchLen.toString(),
          '--output-file-path', outputCircuitInputJson,
          '--proving-framework', 'noir',
        ], {
          cwd: config.projectRoot,
          showOutput: true,
        });

        if (result.success) {
          logger.info(`    Successfully generated: ${outputCircuitInputJson}`);
        } else {
          logger.error(`    Error generating input for pass case: ${templateName} - pass ${index}`);
        }
      }
    } else {
      logger.info(`  No 'pass' cases found for ${templateName}.`);
    }

    // Process "fail" cases
    const failHaystacks = sampleData.fail || [];
    if (failHaystacks.length > 0) {
      for (const [index, haystack] of failHaystacks.entries()) {
        if (!haystack) continue; // Skip empty haystacks

        logger.info(`  Attempting to generate 'fail' input ${index} for ${templateName} (expected to fail)...`);
        const tempFailOutput = path.join(
          config.directories.circuitInputs,
          `${templateName}_fail_${index}_temp.json`
        );

        const result = executeCargo('run', [
          '--quiet',
          '--bin', 'zk-regex',
          'generate-circuit-input',
          '--graph-path', graphPath,
          '--input', haystack,
          '--max-haystack-len', config.maxHaystackLen.toString(),
          '--max-match-len', config.maxMatchLen.toString(),
          '--output-file-path', tempFailOutput,
          '--proving-framework', 'noir',
        ], {
          cwd: config.projectRoot,
          showOutput: false,
        });

        if (!result.success) {
          logger.info(`    Input generation failed as expected for: ${templateName} - fail ${index}`);
          if (await fileExists(tempFailOutput)) {
            await removeFile(tempFailOutput);
          }
        } else {
          const warningMessage = `    Warning: Input generation SUCCEEDED for 'fail' case: ${templateName} - fail ${index}.`;
          logger.warn(warningMessage);
          
          unexpectedSuccesses.push({
            templateName,
            failCaseIndex: index,
            haystack,
          });

          if (config.saveInputsForSuccessfulFailCases) {
            const finalFailOutputName = path.join(
              config.directories.circuitInputs,
              `${templateName}_fail_${index}_unexpected_success.json`
            );
            // Move file (TypeScript doesn't have shutil.move, use rename)
            if (await fileExists(tempFailOutput)) {
              await writeTextFile(finalFailOutputName, await readTextFile(tempFailOutput));
              await removeFile(tempFailOutput);
              logger.info(`      Input saved to ${finalFailOutputName}`);
            }
          } else {
            if (await fileExists(tempFailOutput)) {
              await removeFile(tempFailOutput);
            }
          }
        }
      }
    } else {
      logger.info(`  No 'fail' cases found for ${templateName}.`);
    }
    logger.info('---');
  }

  return unexpectedSuccesses;
}

/**
 * Add tests to Noir circuits
 */
async function addTestsToNoirCircuits(): Promise<void> {
  logger.info('Phase 2: Adding tests to Noir circuits...');
  
  const circuitNrFiles = await globFiles(config.directories.circuits, '*_regex.nr');

  for (const circuitNrFile of circuitNrFiles) {
    if (!(await fileExists(circuitNrFile))) {
      logger.info(`Skipping non-file: ${circuitNrFile}`);
      continue;
    }

    const templateName = path.parse(circuitNrFile).name.replace('_regex', '');
    logger.info(`Processing circuit: ${circuitNrFile} (template: ${templateName})`);

    let circuitContentLines: string[];
    try {
      const circuitContent = await readTextFile(circuitNrFile);
      circuitContentLines = circuitContent.split('\n');
    } catch (error) {
      logger.error(`  Error reading ${circuitNrFile}: ${error}. Skipping.`);
      continue;
    }

    // Replace "use zkregex::" with "use crate::"
    let importsModified = false;
    for (let i = 0; i < circuitContentLines.length; i++) {
      if (circuitContentLines[i]!.trim().startsWith('use zkregex::')) {
        circuitContentLines[i] = circuitContentLines[i]!.replace('use zkregex::', 'use crate::');
        importsModified = true;
      }
    }

    if (importsModified) {
      logger.info(`  Updated 'use zkregex::' to 'use crate::' in ${circuitNrFile}.`);
    }

    // Remove existing #[cfg(test)] mod tests { ... } block
    const { updatedLines, modTestsRemoved } = removeExistingTestsBlock(circuitContentLines);
    circuitContentLines = updatedLines;

    if (modTestsRemoved) {
      logger.info('  Removed existing \'mod tests { ... }\' block.');
    }

    const circuitContentStr = circuitContentLines.join('\n');
    const linesToAppendToFile: string[] = [];
    let globalsAddedThisRun = false;

    // Check and prepare MAX_HAYSTACK_LEN and MAX_MATCH_LEN if not present globally
    if (!circuitContentStr.match(/^global MAX_HAYSTACK_LEN: u32\s*=\s*\d+;/m)) {
      linesToAppendToFile.push(`global MAX_HAYSTACK_LEN: u32 = ${config.maxHaystackLen};`);
      globalsAddedThisRun = true;
      logger.info(`  Prepared global MAX_HAYSTACK_LEN = ${config.maxHaystackLen}.`);
    }

    if (!circuitContentStr.match(/^global MAX_MATCH_LEN: u32\s*=\s*\d+;/m)) {
      linesToAppendToFile.push(`global MAX_MATCH_LEN: u32 = ${config.maxMatchLen};`);
      globalsAddedThisRun = true;
      logger.info(`  Prepared global MAX_MATCH_LEN = ${config.maxMatchLen}.`);
    }

    if (globalsAddedThisRun && linesToAppendToFile.length > 0) {
      linesToAppendToFile.push(''); // Add newline after globals
    }

    // Extract number of capture groups
    let numCaptureGroupsInCircuit = 0;
    const numCgMatch = circuitContentStr.match(/pub global NUM_CAPTURE_GROUPS: u32\s*=\s*(\d+);/);
    if (numCgMatch) {
      numCaptureGroupsInCircuit = parseInt(numCgMatch[1]!, 10);
    }

    // Find pass input JSON files
    const passInputJsonFiles = await globFiles(
      config.directories.circuitInputs,
      `${templateName}_pass_*.json`
    );

    if (passInputJsonFiles.length === 0 && !globalsAddedThisRun && !importsModified && !modTestsRemoved) {
      logger.info(`  No pass case circuit inputs found for ${templateName} and no other changes. No tests added or file modified.`);
      continue;
    }

    let newTestsGeneratedThisRun = false;
    
    for (const inputJsonFile of passInputJsonFiles) {
      const indexMatch = inputJsonFile.match(new RegExp(`${templateName}_pass_(\\d+)\\.json$`));
      if (!indexMatch) continue;
      
      const index = indexMatch[1]!;
      const testFnName = `test_${templateName}_pass_${index}`;

      // Check if test function already exists
      const currentFullContent = circuitContentLines.join('\n') + linesToAppendToFile.join('\n');
      if (currentFullContent.includes(`fn ${testFnName}()`)) {
        logger.info(`  Test function ${testFnName} already exists or is pending. Skipping.`);
        continue;
      }

      logger.info(`  Generating test function: ${testFnName}`);
      newTestsGeneratedThisRun = true;

      try {
        const inputData = await readJsonFile<CircuitInput>(inputJsonFile);
        const testFunctionContent = generateTestFunction(testFnName, inputData, numCaptureGroupsInCircuit);
        linesToAppendToFile.push(...testFunctionContent);
        linesToAppendToFile.push(''); // Blank line after test function
      } catch (error) {
        logger.error(`    Error reading or parsing input JSON ${inputJsonFile}: ${error}. Skipping this test.`);
        continue;
      }
    }

    // Write updated file if any changes were made
    const madeActualChanges = importsModified || modTestsRemoved || globalsAddedThisRun || newTestsGeneratedThisRun;

    if (linesToAppendToFile.length > 0 || madeActualChanges) {
      const finalContent = circuitContentLines.join('\n') + '\n' + linesToAppendToFile.join('\n');
      try {
        await writeTextFile(circuitNrFile, finalContent);
        logger.info(`  Successfully updated ${circuitNrFile}.`);
      } catch (error) {
        logger.error(`  Error writing updated tests to ${circuitNrFile}: ${error}`);
      }
    } else {
      logger.info(`  No new tests were added and no modifications made to ${circuitNrFile}.`);
    }
    
    logger.info('---');
  }
}

/**
 * Remove existing test block from circuit content
 */
function removeExistingTestsBlock(lines: string[]): { updatedLines: string[]; modTestsRemoved: boolean } {
  let modTestsRemoved = false;
  let modTestsStartIndex = -1;

  // Find the start of the mod tests block
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!.trim();
    const nextLine = i + 1 < lines.length ? lines[i + 1]!.trim() : '';

    if (line.startsWith('#[cfg(test)]') && nextLine.includes('mod tests') && nextLine.endsWith('{')) {
      modTestsStartIndex = i;
      break;
    } else if (line.startsWith('#[cfg(test)] mod tests')) {
      modTestsStartIndex = i;
      break;
    }
  }

  if (modTestsStartIndex !== -1) {
    let braceCount = 0;
    let modTestsEndIndex = -1;
    let blockStartLineIndex = modTestsStartIndex;

    // Find the opening brace
    for (let i = modTestsStartIndex; i < lines.length; i++) {
      if (lines[i]!.includes('{')) {
        blockStartLineIndex = i;
        break;
      }
    }

    // Count braces to find the end of the block
    for (let i = blockStartLineIndex; i < lines.length; i++) {
      braceCount += (lines[i]!.match(/\{/g) || []).length;
      braceCount -= (lines[i]!.match(/\}/g) || []).length;

      if (braceCount === 0 && i >= blockStartLineIndex) {
        const firstBraceOnThisLine = lines[i]!.includes('{') && i === blockStartLineIndex;
        if (!(firstBraceOnThisLine && (lines[i]!.match(/\{/g) || []).length > (lines[i]!.match(/\}/g) || []).length)) {
          modTestsEndIndex = i;
          break;
        }
      }
    }

    if (modTestsEndIndex !== -1) {
      lines.splice(modTestsStartIndex, modTestsEndIndex - modTestsStartIndex + 1);
      modTestsRemoved = true;
    }
  }

  return { updatedLines: lines, modTestsRemoved };
}

/**
 * Generate test function content
 */
function generateTestFunction(testFnName: string, inputData: CircuitInput, numCaptureGroups: number): string[] {
  const inHaystackVal = inputData.in_haystack.map(x => x.toString()).join(', ');
  const matchStartVal = inputData.match_start;
  const matchLengthVal = inputData.match_length;
  const currStatesVal = inputData.curr_states.map(x => x.toString()).join(', ');
  const nextStatesVal = inputData.next_states.map(x => x.toString()).join(', ');

  const testFnContentList = [
    '#[test]',
    `fn ${testFnName}() {`,
    `    let in_haystack: [u8; MAX_HAYSTACK_LEN] = [${inHaystackVal}];`,
    `    let match_start: u32 = ${matchStartVal};`,
    `    let match_length: u32 = ${matchLengthVal};`,
    `    let current_states: [Field; MAX_MATCH_LEN] = [${currStatesVal}];`,
    `    let next_states: [Field; MAX_MATCH_LEN] = [${nextStatesVal}];`,
  ];

  const callParams = [
    'in_haystack',
    'match_start', 
    'match_length',
    'current_states',
    'next_states',
  ];

  if (numCaptureGroups > 0) {
    const cgStartIndices = (inputData.capture_group_start_indices || Array(numCaptureGroups).fill(0))
      .map(x => x.toString()).join(', ');
    
    testFnContentList.push(`    let capture_group_start_indices_val: [Field; NUM_CAPTURE_GROUPS] = [${cgStartIndices}];`);

    const cgIdParamNames: string[] = [];
    const cgStartParamNames: string[] = [];

    for (let cgIdx = 1; cgIdx <= numCaptureGroups; cgIdx++) {
      const cgIds = inputData.capture_group_ids?.[cgIdx - 1] || [];
      const cgStarts = inputData.capture_group_starts?.[cgIdx - 1] || [];

      const currentCgIdsVal = cgIds.map(x => x.toString()).join(', ');
      const currentCgStartsVal = cgStarts.map(x => x.toString()).join(', ');

      testFnContentList.push(`    let capture_group_${cgIdx}_id: [Field; MAX_MATCH_LEN] = [${currentCgIdsVal}];`);
      testFnContentList.push(`    let capture_group_${cgIdx}_start: [Field; MAX_MATCH_LEN] = [${currentCgStartsVal}];`);

      cgIdParamNames.push(`capture_group_${cgIdx}_id`);
      cgStartParamNames.push(`capture_group_${cgIdx}_start`);
    }

    callParams.push(...cgIdParamNames, ...cgStartParamNames, 'capture_group_start_indices_val');
  }

  const callParamsStr = callParams.join(', ');
  const regexMatchCallBase = `regex_match::<MAX_HAYSTACK_LEN, MAX_MATCH_LEN>(${callParamsStr})`;

  if (numCaptureGroups === 1) {
    testFnContentList.push(`    let capture_1 = ${regexMatchCallBase};`);
  } else if (numCaptureGroups > 1) {
    const captureVarsList = Array.from({ length: numCaptureGroups }, (_, i) => `capture_${i + 1}`);
    const captureVars = `(${captureVarsList.join(', ')})`;
    testFnContentList.push(`    let ${captureVars} = ${regexMatchCallBase};`);
  } else {
    testFnContentList.push(`    ${regexMatchCallBase};`);
  }

  testFnContentList.push('}');
  return testFnContentList;
}

/**
 * Main function
 */
async function main(): Promise<void> {
  try {
    process.chdir(config.projectRoot);
    logger.info(`Changed working directory to: ${process.cwd()}`);

    if (!checkJq()) {
      logger.warn(
        'jq could not be found. While this TypeScript script doesn\'t directly use jq for parsing, ' +
        'the overall workflow might depend on it for other parts if not fully migrated.'
      );
    }

    await ensureDirectory(config.directories.circuitInputs);

    logger.info('Starting input generation and test scaffolding...');
    logger.info(`Sample haystacks source: ${config.directories.sampleHaystacks}`);
    logger.info(`Graphs source: ${config.directories.graphs}`);
    logger.info(`Circuit inputs destination: ${config.directories.circuitInputs}`);
    logger.info(`Noir circuits to update: ${config.directories.circuits}`);
    logger.info('---');

    const unexpectedFailSuccesses = await generateCircuitInputs();
    await addTestsToNoirCircuits();

    if (unexpectedFailSuccesses.length > 0) {
      logger.info('\n--- SUMMARY OF UNEXPECTED SUCCESSES FOR \'FAIL\' CASES ---');
      logger.info('The following \'fail\' cases unexpectedly resulted in successful input generation:');
      for (const item of unexpectedFailSuccesses) {
        logger.info(`  - Template: ${item.templateName}, Fail Case Index: ${item.failCaseIndex}, Haystack: "${item.haystack}"`);
      }
      logger.info('Please review these cases to ensure the regex and test data are correct.');
      logger.info('---');
    }

    logger.info('Script finished successfully.');

  } catch (error) {
    if (error instanceof ScriptError) {
      logger.error(error.message);
      if (error.cause) {
        logger.debug('Underlying error:', { error: error.cause.message });
      }
    } else {
      logger.error('An unexpected error occurred:', { 
        error: error instanceof Error ? error.message : String(error) 
      });
    }
    process.exit(1);
  }
}

// Run the script if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    logger.error('Unhandled error in main:', { error: error.message });
    process.exit(1);
  });
}