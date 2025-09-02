#!/usr/bin/env node

/**
 * TypeScript version of gen_regex.py
 * Generates Circom regex circuits from JSON definitions
 */

import * as path from 'path';
import { fileURLToPath } from 'url';
import { 
  logger, 
  toPascalCase, 
  ensureDirectory, 
  listFilesWithExtension,
  fileExists,
  executeCargo,
  ScriptError 
} from '../../scripts/utils/index.js';

// Get current file directory (equivalent to __file__ in Python)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Main function that processes all JSON files and generates Circom circuits
 */
async function main(): Promise<void> {
  try {
    // Calculate project root (accounting for dist directory if compiled)
    // If running from dist/circom/scripts/, go up to zk-regex root
    // If running from circom/scripts/, go up to zk-regex root
    const projectRoot = __dirname.includes('/dist/') 
      ? path.resolve(__dirname, '..', '..', '..', '..') 
      : path.resolve(__dirname, '..', '..');
    
    // Define paths
    const compilerExecutable = path.join(projectRoot, 'target', 'release', 'zk-regex');
    const regexDir = path.join(projectRoot, 'circom', 'regexes');
    const outputDir = path.join(projectRoot, 'circom', 'circuits', 'common');
    const provingFramework = 'circom';

    logger.info(`Project root: ${projectRoot}`);

    // Validate compiler executable exists
    if (!(await fileExists(compilerExecutable))) {
      throw new ScriptError(
        `Compiler executable not found at ${compilerExecutable}. ` +
        'Please build the compiler first (e.g., cargo build in the compiler directory).'
      );
    }

    // Validate regex directory exists
    if (!(await fileExists(regexDir))) {
      throw new ScriptError(`Regex directory not found at ${regexDir}`);
    }

    // Ensure output directory exists
    await ensureDirectory(outputDir);
    logger.info(`Ensured output directory exists: ${outputDir}`);

    // Get all JSON files in regex directory
    logger.info(`Scanning for JSON files in: ${regexDir}`);
    const jsonFiles = await listFilesWithExtension(regexDir, '.json');

    if (jsonFiles.length === 0) {
      logger.warn('No JSON files found in regex directory');
      return;
    }

    // Process each JSON file
    for (const filename of jsonFiles) {
      const jsonFilePath = path.join(regexDir, filename);
      const baseName = path.parse(filename).name;

      // Convert base_name to PascalCase
      const templateName = toPascalCase(baseName);

      logger.info(`\nProcessing ${filename}...`);
      logger.info(`  Input JSON: ${jsonFilePath}`);
      logger.info(`  Template Name: ${templateName}`);
      logger.info(`  Output Directory: ${outputDir}`);

      // Execute the compiler
      const result = executeCargo('run', [
        '--bin', 'zk-regex',
        'decomposed',
        '-d', jsonFilePath,
        '-o', outputDir,
        '-t', templateName,
        '-p', provingFramework,
      ], {
        cwd: projectRoot,
        showOutput: true,
      });

      if (result.success) {
        logger.info(`  Successfully generated files for ${templateName}`);
      } else {
        logger.error(`  Error processing ${filename}:`, {
          returnCode: 'Non-zero exit',
          stdout: result.stdout,
          stderr: result.stderr,
        });
        
        // Continue processing other files even if one fails
        continue;
      }
    }

    logger.info('\nScript finished successfully.');

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