import { describe, it, expect } from 'bun:test';
import {
  detectPlatform,
  getTimeCommand,
  parseTimeOutput,
  calculateMemoryStats,
  defaultMemoryStats,
  formatMemoryStats,
} from '../../src/utils/memory.js';

describe('memory utilities', () => {
  describe('detectPlatform', () => {
    it('returns a valid platform', () => {
      const platform = detectPlatform();
      expect(['darwin', 'linux', 'unsupported']).toContain(platform);
    });
  });

  describe('getTimeCommand', () => {
    it('returns correct command for darwin', () => {
      const cmd = getTimeCommand('darwin');
      expect(cmd).toBe('/usr/bin/time -l');
    });

    it('returns correct command for linux', () => {
      const cmd = getTimeCommand('linux');
      expect(cmd).toBe('/usr/bin/time -v');
    });

    it('returns null for unsupported platforms', () => {
      const cmd = getTimeCommand('unsupported');
      expect(cmd).toBeNull();
    });
  });

  describe('parseTimeOutput', () => {
    it('parses macOS BSD time output (bytes)', () => {
      // macOS time -l outputs bytes
      const output = `        104857600  maximum resident set size`;
      const mb = parseTimeOutput(output, 'darwin');
      expect(mb).toBeCloseTo(100, 1); // 100 MB
    });

    it('parses macOS BSD time output with different formatting', () => {
      const output = `
        1.23 real         0.50 user         0.30 sys
             209715200  maximum resident set size
                     0  average shared memory size
      `;
      const mb = parseTimeOutput(output, 'darwin');
      expect(mb).toBeCloseTo(200, 1); // 200 MB
    });

    it('parses Linux GNU time output (kilobytes)', () => {
      // Linux time -v outputs kilobytes
      const output = `Maximum resident set size (kbytes): 102400`;
      const mb = parseTimeOutput(output, 'linux');
      expect(mb).toBeCloseTo(100, 1); // 100 MB
    });

    it('parses Linux GNU time verbose output', () => {
      const output = `
        Command being timed: "echo hello"
        User time (seconds): 0.00
        System time (seconds): 0.00
        Maximum resident set size (kbytes): 204800
        Exit status: 0
      `;
      const mb = parseTimeOutput(output, 'linux');
      expect(mb).toBeCloseTo(200, 1); // 200 MB
    });

    it('returns 0 for unparseable output', () => {
      expect(parseTimeOutput('garbage data', 'darwin')).toBe(0);
      expect(parseTimeOutput('garbage data', 'linux')).toBe(0);
    });

    it('returns 0 for empty output', () => {
      expect(parseTimeOutput('', 'darwin')).toBe(0);
      expect(parseTimeOutput('', 'linux')).toBe(0);
    });

    it('returns 0 for unsupported platform', () => {
      expect(parseTimeOutput('any output', 'unsupported')).toBe(0);
    });
  });

  describe('calculateMemoryStats', () => {
    it('calculates correct statistics', () => {
      const measurements = [100, 110, 90, 105, 95];
      const stats = calculateMemoryStats(measurements);

      expect(stats.mean).toBe(100);
      expect(stats.min).toBe(90);
      expect(stats.max).toBe(110);
      expect(stats.runs).toBe(5);
      expect(stats.measured).toBe(true);
      expect(stats.stddev).toBeCloseTo(7.91, 1);
    });

    it('handles empty array', () => {
      const stats = calculateMemoryStats([]);

      expect(stats.mean).toBe(0);
      expect(stats.stddev).toBe(0);
      expect(stats.runs).toBe(0);
      expect(stats.measured).toBe(false);
    });

    it('handles single value', () => {
      const stats = calculateMemoryStats([256]);

      expect(stats.mean).toBe(256);
      expect(stats.stddev).toBe(0);
      expect(stats.min).toBe(256);
      expect(stats.max).toBe(256);
      expect(stats.runs).toBe(1);
      expect(stats.measured).toBe(true);
    });

    it('respects measured flag parameter', () => {
      const stats = calculateMemoryStats([100, 200], false);
      expect(stats.measured).toBe(false);
    });
  });

  describe('defaultMemoryStats', () => {
    it('returns zeroed stats with measured=false', () => {
      const stats = defaultMemoryStats();

      expect(stats.mean).toBe(0);
      expect(stats.stddev).toBe(0);
      expect(stats.min).toBe(0);
      expect(stats.max).toBe(0);
      expect(stats.runs).toBe(0);
      expect(stats.measured).toBe(false);
    });
  });

  describe('formatMemoryStats', () => {
    it('formats measured stats for display', () => {
      const stats = {
        mean: 512.5,
        stddev: 25.3,
        min: 480,
        max: 550,
        runs: 5,
        measured: true,
      };

      const formatted = formatMemoryStats(stats);
      expect(formatted).toBe('513 ± 25 MB (5 runs)');
    });

    it('returns N/A for unmeasured stats', () => {
      const stats = {
        mean: 0,
        stddev: 0,
        min: 0,
        max: 0,
        runs: 0,
        measured: false,
      };

      expect(formatMemoryStats(stats)).toBe('N/A');
    });

    it('returns N/A for zero mean', () => {
      const stats = {
        mean: 0,
        stddev: 0,
        min: 0,
        max: 0,
        runs: 3,
        measured: true,
      };

      expect(formatMemoryStats(stats)).toBe('N/A');
    });
  });
});
