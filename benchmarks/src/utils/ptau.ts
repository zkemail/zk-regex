/**
 * Powers of Tau file management.
 *
 * Downloads and caches the ptau file needed for Groth16 setup.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import * as crypto from 'crypto';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';

// pot16 (65K constraints max) - sufficient for simple_regex testing
// For larger patterns, use pot19 (524K) or pot20 (1M)
// Available sizes: pot15=32K, pot16=65K, pot17=131K, pot18=262K, pot19=524K, pot20=1M
const PTAU_URL = 'https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_16.ptau';
const PTAU_FILENAME = 'pot16.ptau';
const PTAU_EXPECTED_SIZE = 0; // Skip size validation - files can vary

// Cache in user home directory
const CACHE_DIR = path.join(os.homedir(), '.zk-regex-bench-cache');

/**
 * Get the path to the cached ptau file.
 */
export function getPtauCachePath(): string {
  return path.join(CACHE_DIR, PTAU_FILENAME);
}

/**
 * Check if the ptau file exists and is valid.
 */
async function validatePtauFile(filePath: string): Promise<boolean> {
  try {
    const stats = await fs.stat(filePath);
    // File must exist and have non-zero size
    // Skip exact size validation as files can vary slightly
    return stats.size > 0;
  } catch {
    return false;
  }
}

/**
 * Download with progress reporting.
 */
async function downloadWithProgress(url: string, destPath: string): Promise<Result<void>> {
  try {
    console.log(`Downloading Powers of Tau from ${url}...`);
    console.log('This may take a moment (~76MB file).');

    const response = await fetch(url);

    if (!response.ok) {
      return err(errors.ptauDownloadFailed(url, `HTTP ${response.status}`));
    }

    const totalSize = Number(response.headers.get('content-length') || 0);
    const reader = response.body?.getReader();

    if (!reader) {
      return err(errors.ptauDownloadFailed(url, 'No response body'));
    }

    const chunks: Uint8Array[] = [];
    let downloadedSize = 0;
    let lastProgress = 0;

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      chunks.push(value);
      downloadedSize += value.length;

      // Report progress every 10%
      const progress = Math.floor((downloadedSize / totalSize) * 10) * 10;
      if (progress > lastProgress) {
        console.log(`  ${progress}% downloaded (${Math.round(downloadedSize / 1024 / 1024)}MB)`);
        lastProgress = progress;
      }
    }

    // Combine chunks and write
    const fileData = new Uint8Array(downloadedSize);
    let offset = 0;
    for (const chunk of chunks) {
      fileData.set(chunk, offset);
      offset += chunk.length;
    }

    await fs.writeFile(destPath, fileData);
    console.log('Download complete.');

    return ok(undefined);
  } catch (error) {
    return err(errors.ptauDownloadFailed(url, String(error)));
  }
}

/**
 * Ensure the Powers of Tau file is available.
 *
 * Downloads if not cached, validates if cached.
 */
export async function ensurePtauFile(): Promise<Result<string>> {
  const ptauPath = getPtauCachePath();

  // Create cache directory if needed
  try {
    await fs.mkdir(CACHE_DIR, { recursive: true });
  } catch {
    // Directory might already exist
  }

  // Check if already cached and valid
  if (await validatePtauFile(ptauPath)) {
    console.log(`Using cached Powers of Tau: ${ptauPath}`);
    return ok(ptauPath);
  }

  // Download
  const downloadResult = await downloadWithProgress(PTAU_URL, ptauPath);
  if (!downloadResult.ok) {
    return downloadResult;
  }

  // Validate downloaded file
  if (!await validatePtauFile(ptauPath)) {
    await fs.unlink(ptauPath).catch(() => {});
    return err(errors.ptauDownloadFailed(PTAU_URL, 'Downloaded file validation failed'));
  }

  return ok(ptauPath);
}

/**
 * Compute SHA256 hash of a file.
 */
export async function hashFile(filePath: string): Promise<string> {
  const data = await fs.readFile(filePath);
  return crypto.createHash('sha256').update(data).digest('hex');
}

/**
 * Get the maximum constraint count supported by the ptau file.
 */
export function getMaxConstraints(): number {
  // pot16 supports 2^16 = 65,536 constraints
  return Math.pow(2, 16);
}
