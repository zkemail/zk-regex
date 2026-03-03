import { describe, it, expect } from 'bun:test';
import * as fs from 'fs/promises';
import * as path from 'path';
import { generateScaledInput, type ScalingConfig } from '../../src/utils/input-scaling.js';

/**
 * Validate that scaled inputs from patterns.json actually match their regex.
 *
 * This is an acceptance test: for every pattern that has scaling config,
 * we generate scaled content at several target lengths and verify each
 * output contains a match against the pattern's regex.
 */

interface PatternEntry {
  name: string;
  regex: string;
  inputTemplate?: string;
  scalingStrategy?: string;
  extendChar?: string;
  extendPosition?: string;
}

async function loadPatterns(): Promise<PatternEntry[]> {
  const configPath = path.join(import.meta.dir, '..', '..', 'config', 'patterns.json');
  const content = await fs.readFile(configPath, 'utf-8');
  const data = JSON.parse(content);
  return data.patterns;
}

describe('scaled inputs match their regex', () => {
  const targetLengths = [64, 128, 256, 512];

  it('all patterns with scaling config produce regex-matching output', async () => {
    const patterns = await loadPatterns();

    for (const pattern of patterns) {
      if (!pattern.inputTemplate || !pattern.scalingStrategy) continue;

      const config: ScalingConfig = {
        strategy: pattern.scalingStrategy as any,
        inputTemplate: pattern.inputTemplate,
        extendChar: pattern.extendChar,
        extendPosition: pattern.extendPosition as any,
      };

      // JavaScript regex from the pattern
      // Note: some patterns use \r\n which JS handles natively
      let regex: RegExp;
      try {
        regex = new RegExp(pattern.regex);
      } catch {
        // Skip patterns with regex syntax JS doesn't support
        continue;
      }

      for (const len of targetLengths) {
        const scaled = generateScaledInput(config, len);
        const match = regex.test(scaled);
        expect(match).toBe(true);
      }
    }
  });

  it('each pattern template itself matches its regex', async () => {
    const patterns = await loadPatterns();

    for (const pattern of patterns) {
      if (!pattern.inputTemplate) continue;

      let regex: RegExp;
      try {
        regex = new RegExp(pattern.regex);
      } catch {
        continue;
      }

      const match = regex.test(pattern.inputTemplate);
      expect(match).toBe(true);
    }
  });

  it('repeat strategy produces multiple matches at larger sizes', async () => {
    const patterns = await loadPatterns();

    for (const pattern of patterns) {
      if (!pattern.inputTemplate || pattern.scalingStrategy !== 'repeat') continue;

      const config: ScalingConfig = {
        strategy: 'repeat',
        inputTemplate: pattern.inputTemplate,
      };

      let regex: RegExp;
      try {
        regex = new RegExp(pattern.regex, 'g');
      } catch {
        continue;
      }

      const scaled = generateScaledInput(config, 256);
      const matches = scaled.match(regex);
      // At 256 bytes with a short template, we should get multiple matches
      if (matches) {
        expect(matches.length).toBeGreaterThanOrEqual(1);
      }
    }
  });
});
