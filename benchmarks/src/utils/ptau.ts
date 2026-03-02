/**
 * Powers of Tau file management.
 *
 * Downloads and caches the ptau file needed for Groth16 setup.
 * Configuration is read from benchmarks/config/benchmark.json.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import { fileURLToPath } from 'url';
import type { Result } from '../errors.js';
import { ok, err, errors } from '../errors.js';
import type { PtauConfig } from '../types.js';

// Cache in user home directory
const CACHE_DIR = path.join(os.homedir(), '.zk-regex-bench-cache');

// Cached config to avoid repeated file reads
let cachedConfig: PtauConfig | null = null;

/**
 * Load PTAU configuration from benchmark.json.
 */
async function loadPtauConfig(): Promise<PtauConfig> {
  if (cachedConfig) return cachedConfig;

  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const configPath = path.join(__dirname, '../../config/benchmark.json');
  const configContent = await fs.readFile(configPath, 'utf-8');
  const config = JSON.parse(configContent);
  cachedConfig = config.ptau as PtauConfig;
  return cachedConfig;
}

/**
 * Get the path to the cached ptau file.
 */
export async function getPtauCachePath(): Promise<string> {
  const config = await loadPtauConfig();
  return path.join(CACHE_DIR, config.filename);
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
    console.log('This may take a moment depending on the pot file size.');

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
  const config = await loadPtauConfig();
  const ptauPath = path.join(CACHE_DIR, config.filename);

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
  const downloadResult = await downloadWithProgress(config.url, ptauPath);
  if (!downloadResult.ok) {
    return downloadResult;
  }

  // Validate downloaded file
  if (!await validatePtauFile(ptauPath)) {
    await fs.unlink(ptauPath).catch(() => {});
    return err(errors.ptauDownloadFailed(config.url, 'Downloaded file validation failed'));
  }

  return ok(ptauPath);
}

/**
 * Extract the power from a ptau filename (e.g., "pot16.ptau" -> 16).
 * The power determines max constraints as 2^power.
 */
function extractPowerFromFilename(filename: string): number | null {
  // Match patterns like "pot16.ptau", "powersOfTau28_hez_final_16.ptau"
  const match = filename.match(/(\d+)\.ptau$/);
  if (match) {
    return parseInt(match[1], 10);
  }
  return null;
}

/**
 * Get the maximum constraint count supported by the ptau file.
 * Calculated from the pot power in the filename (e.g., pot16 = 2^16 = 65536).
 */
export async function getMaxConstraints(): Promise<number> {
  const config = await loadPtauConfig();
  const power = extractPowerFromFilename(config.filename);
  if (power === null) {
    throw new Error(
      `Cannot determine max constraints from ptau filename "${config.filename}". ` +
      `Expected format like "pot16.ptau" where 16 is the power of 2.`
    );
  }
  return Math.pow(2, power);
}
