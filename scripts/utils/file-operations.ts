import { promises as fs } from 'fs';
import * as path from 'path';
import { ScriptError } from './types.js';
import { logger } from './logger.js';

/**
 * Safe file operation wrapper that provides consistent error handling
 */
export async function safeFileOperation<T>(
  operation: () => Promise<T>,
  errorMessage: string
): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    throw new ScriptError(errorMessage, err);
  }
}

/**
 * Ensures a directory exists, creating it if necessary
 */
export async function ensureDirectory(dirPath: string): Promise<void> {
  await safeFileOperation(
    () => fs.mkdir(dirPath, { recursive: true }),
    `Failed to create directory: ${dirPath}`
  );
  logger.debug(`Ensured directory exists: ${dirPath}`);
}

/**
 * Safely reads and parses a JSON file
 */
export async function readJsonFile<T = unknown>(filePath: string): Promise<T> {
  return safeFileOperation(async () => {
    const content = await fs.readFile(filePath, 'utf8');
    return JSON.parse(content) as T;
  }, `Failed to read JSON file: ${filePath}`);
}

/**
 * Safely writes a JSON object to a file
 */
export async function writeJsonFile<T>(filePath: string, data: T): Promise<void> {
  await safeFileOperation(
    () => fs.writeFile(filePath, JSON.stringify(data, null, 2)),
    `Failed to write JSON file: ${filePath}`
  );
}

/**
 * Safely reads a text file
 */
export async function readTextFile(filePath: string): Promise<string> {
  return safeFileOperation(
    () => fs.readFile(filePath, 'utf8'),
    `Failed to read text file: ${filePath}`
  );
}

/**
 * Safely writes a text file
 */
export async function writeTextFile(filePath: string, content: string): Promise<void> {
  await safeFileOperation(
    () => fs.writeFile(filePath, content),
    `Failed to write text file: ${filePath}`
  );
}

/**
 * Checks if a file exists
 */
export async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

/**
 * Checks if a directory exists
 */
export async function directoryExists(dirPath: string): Promise<boolean> {
  try {
    const stats = await fs.stat(dirPath);
    return stats.isDirectory();
  } catch {
    return false;
  }
}

/**
 * Lists all files in a directory with a specific extension
 */
export async function listFilesWithExtension(dirPath: string, extension: string): Promise<string[]> {
  return safeFileOperation(async () => {
    const files = await fs.readdir(dirPath);
    return files.filter(file => file.endsWith(extension));
  }, `Failed to list files in directory: ${dirPath}`);
}

/**
 * Safely moves a file from source to destination
 */
export async function moveFile(src: string, dest: string): Promise<void> {
  await safeFileOperation(
    () => fs.rename(src, dest),
    `Failed to move file from ${src} to ${dest}`
  );
  logger.info(`Moved ${src} to ${dest}`);
}

/**
 * Safely removes a file
 */
export async function removeFile(filePath: string): Promise<void> {
  await safeFileOperation(
    () => fs.unlink(filePath),
    `Failed to remove file: ${filePath}`
  );
}

/**
 * Safely removes a directory and its contents
 */
export async function removeDirectory(dirPath: string): Promise<void> {
  await safeFileOperation(
    () => fs.rm(dirPath, { recursive: true, force: true }),
    `Failed to remove directory: ${dirPath}`
  );
}

/**
 * Gets the absolute path from a relative path based on project root
 */
export function getAbsolutePath(relativePath: string, projectRoot: string): string {
  return path.resolve(projectRoot, relativePath);
}

/**
 * Process multiple files in parallel with a given operation
 */
export async function processFilesParallel<T>(
  filePaths: string[],
  operation: (filePath: string) => Promise<T>,
  concurrency: number = 5
): Promise<T[]> {
  const results: T[] = [];
  
  // Process files in batches to avoid overwhelming the system
  for (let i = 0; i < filePaths.length; i += concurrency) {
    const batch = filePaths.slice(i, i + concurrency);
    const batchPromises = batch.map(operation);
    const batchResults = await Promise.all(batchPromises);
    results.push(...batchResults);
  }
  
  return results;
}

/**
 * Read multiple JSON files in parallel
 */
export async function readJsonFilesParallel<T = unknown>(filePaths: string[]): Promise<T[]> {
  return processFilesParallel(filePaths, (filePath) => readJsonFile<T>(filePath));
}

/**
 * Read multiple text files in parallel
 */
export async function readTextFilesParallel(filePaths: string[]): Promise<string[]> {
  return processFilesParallel(filePaths, readTextFile);
}

/**
 * Simple glob implementation for basic patterns like "*.json"
 */
export async function globFiles(dirPath: string, pattern: string): Promise<string[]> {
  const files = await safeFileOperation(
    () => fs.readdir(dirPath),
    `Failed to read directory: ${dirPath}`
  );
  
  // Convert glob pattern to regex
  const regexPattern = pattern
    .replace(/\./g, '\\.')
    .replace(/\*/g, '.*')
    .replace(/\?/g, '.');
  
  const regex = new RegExp(`^${regexPattern}$`);
  
  return files
    .filter(file => regex.test(file))
    .map(file => path.join(dirPath, file));
}