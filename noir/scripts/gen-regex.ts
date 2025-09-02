#!/usr/bin/env node

/**
 * TypeScript version of gen_regex.py
 * Noir circuit generation with file management and case conversions
 */

import * as path from 'path';
import { fileURLToPath } from 'url';
import { 
  logger, 
  toPascalCase,
  toSnakeCase,
  ensureDirectory, 
  listFilesWithExtension,
  fileExists,
  directoryExists,
  moveFile,
  removeDirectory,
  executeCargo,
  ScriptError 
} from '../../scripts/utils/index.js';

// Get current file directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const SCRIPT_DIR = __dirname;
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..', '..');

// Directories
const NOIR_COMMON_DIR = path.join(PROJECT_ROOT, 'noir', 'common');
const CIRCUITS_DIR = path.join(PROJECT_ROOT, 'noir', 'src', 'templates', 'circuits');
const GRAPHS_DIR = path.join(PROJECT_ROOT, 'noir', 'src', 'templates', 'graphs');
const TEMP_OUTPUT_DIR = path.join(PROJECT_ROOT, 'noir', 'src', 'templates', 'temp_gen');

/**
 * Generate files for a specific regex JSON file
 */
async function generateFiles(regexJsonPath: string): Promise<void> {
  const templateName = path.parse(regexJsonPath).name;

  // Convert template name to PascalCase for the compiler
  let templateNamePascal: string;
  if (templateName.includes('_')) {
    templateNamePascal = templateName.split('_').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
    ).join('');
  } else if (templateName.includes('-')) {
    templateNamePascal = templateName.split('-').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
    ).join('');
  } else {
    // Single word or already camel/pascal case
    templateNamePascal = templateName.length > 1 
      ? templateName.charAt(0).toUpperCase() + templateName.slice(1)
      : templateName.toUpperCase();
  }

  logger.info(
    `Processing ${templateName} (from ${regexJsonPath}), using template name for compiler: ${templateNamePascal}`
  );

  logger.info(`Generating files for ${templateNamePascal}...`);

  try {
    // Execute the cargo command
    const result = executeCargo('run', [
      '--bin', 'zk-regex',
      'decomposed',
      '--decomposed-regex-path', regexJsonPath,
      '--output-file-path', TEMP_OUTPUT_DIR,
      '--template-name', templateNamePascal,
      '--proving-framework', 'noir',
    ], {
      cwd: PROJECT_ROOT,
      showOutput: true,
    });

    if (!result.success) {
      throw new ScriptError(
        `Error running cargo for ${templateNamePascal}: ${result.error?.message || 'Unknown error'}`
      );
    }

    logger.info(`  Cargo command executed successfully for ${templateNamePascal}.`);

  } catch (error) {
    logger.error(`  Error running cargo for ${templateNamePascal}: ${error}`);
    return; // Skip moving files if generation failed
  }

  // Determine the base name the compiler likely used for output files
  const compiledFileBaseName = toSnakeCase(templateNamePascal);

  const generatedRegexNrSource = path.join(TEMP_OUTPUT_DIR, `${compiledFileBaseName}_regex.nr`);
  const generatedGraphJsonSource = path.join(TEMP_OUTPUT_DIR, `${compiledFileBaseName}_graph.json`);

  // Target files should use the original template_name from the .json file
  const targetRegexNr = path.join(CIRCUITS_DIR, `${templateName}_regex.nr`);
  const targetGraphJson = path.join(GRAPHS_DIR, `${templateName}_graph.json`);

  // Move the generated regex.nr file
  if (await fileExists(generatedRegexNrSource)) {
    await moveFile(generatedRegexNrSource, targetRegexNr);
  } else {
    logger.error(`Error: Generated regex file ${generatedRegexNrSource} not found!`);
    logger.error(`Attempted base name for compiler output: ${compiledFileBaseName}`);
  }

  // Move the generated graph.json file
  if (await fileExists(generatedGraphJsonSource)) {
    await moveFile(generatedGraphJsonSource, targetGraphJson);
  } else {
    logger.warn(`Warning: Generated graph file ${generatedGraphJsonSource} not found.`);
    logger.warn(`Attempted base name for compiler output: ${compiledFileBaseName}`);
  }

  logger.info('---');
}

/**
 * Main function
 */
async function main(): Promise<void> {
  try {
    // Change current working directory to project root
    process.chdir(PROJECT_ROOT);
    logger.info(`Changed working directory to: ${process.cwd()}`);

    // Validate noir common directory exists
    if (!(await directoryExists(NOIR_COMMON_DIR))) {
      throw new ScriptError(`Error: Directory ${NOIR_COMMON_DIR} not found.`);
    }

    // Ensure required directories exist
    await ensureDirectory(CIRCUITS_DIR);
    await ensureDirectory(GRAPHS_DIR);
    await ensureDirectory(TEMP_OUTPUT_DIR);

    logger.info(`Target circuits directory: ${CIRCUITS_DIR}`);
    logger.info(`Target graphs directory: ${GRAPHS_DIR}`);

    // Get all JSON files in noir common directory
    const jsonFiles = await listFilesWithExtension(NOIR_COMMON_DIR, '.json');

    if (jsonFiles.length === 0) {
      logger.warn('No JSON files found in noir common directory');
      return;
    }

    // Process each JSON file
    for (const filename of jsonFiles) {
      const regexJsonFile = path.join(NOIR_COMMON_DIR, filename);
      if (await fileExists(regexJsonFile)) {
        await generateFiles(regexJsonFile);
      }
    }

    // Clean up temporary directory
    if (await directoryExists(TEMP_OUTPUT_DIR)) {
      logger.info(`Cleaning up temporary directory: ${TEMP_OUTPUT_DIR}`);
      
      // Safety check before removing directory
      if (TEMP_OUTPUT_DIR && 
          TEMP_OUTPUT_DIR !== '/' && 
          path.basename(TEMP_OUTPUT_DIR) === 'temp_gen') {
        await removeDirectory(TEMP_OUTPUT_DIR);
      } else {
        throw new ScriptError(
          `Error: TEMP_OUTPUT_DIR ('${TEMP_OUTPUT_DIR}') is not set safely or not as expected. Aborting cleanup.`
        );
      }
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