/**
 * Powers of Tau file management.
 *
 * Downloads and caches the ptau file needed for Groth16 setup.
 * Configuration is read from benchmarks/config/benchmark.json.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import { createHash } from 'node:crypto';
import { createReadStream } from 'fs';
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
 * Compute SHA256 hash of a file using streaming reads.
 */
async function computeSha256(filePath: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const hash = createHash('sha256');
    const stream = createReadStream(filePath);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
    stream.on('error', reject);
  });
}

/**
 * Verify a file's SHA256 checksum matches the expected value.
 * Returns the actual hash on mismatch for error reporting.
 */
async function verifyChecksum(
  filePath: string,
  expectedSha256: string,
): Promise<Result<void>> {
  try {
    const actual = await computeSha256(filePath);
    if (actual !== expectedSha256) {
      return err(errors.checksumMismatch(filePath, expectedSha256, actual));
    }
    return ok(undefined);
  } catch {
    return err(errors.fileNotFound(filePath));
  }
}

/**
 * Check if the ptau file exists and has non-zero size.
 */
async function fileExistsWithContent(filePath: string): Promise<boolean> {
  try {
    const stats = await fs.stat(filePath);
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

  // Check if already cached
  if (await fileExistsWithContent(ptauPath)) {
    console.log(`Verifying cached Powers of Tau: ${ptauPath}`);
    const checksumResult = await verifyChecksum(ptauPath, config.sha256);
    if (checksumResult.ok) {
      console.log('Checksum verified.');
      return ok(ptauPath);
    }
    // Cached file is corrupt — delete and re-download
    console.log('Cached file failed checksum verification. Re-downloading...');
    await fs.unlink(ptauPath).catch(() => {});
  }

  // Download
  const downloadResult = await downloadWithProgress(config.url, ptauPath);
  if (!downloadResult.ok) {
    return downloadResult;
  }

  // Verify downloaded file
  if (!await fileExistsWithContent(ptauPath)) {
    return err(errors.ptauDownloadFailed(config.url, 'Downloaded file is empty'));
  }

  const checksumResult = await verifyChecksum(ptauPath, config.sha256);
  if (!checksumResult.ok) {
    await fs.unlink(ptauPath).catch(() => {});
    return checksumResult;
  }

  console.log('Download checksum verified.');
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
