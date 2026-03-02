import { describe, it, expect } from 'bun:test';
import { calculateStats, isHighVariance, formatTimingStats } from '../../src/utils/timing.js';

describe('timing utilities', () => {
  describe('calculateStats', () => {
    it('calculates correct statistics', () => {
      const times = [100, 110, 90, 105, 95];
      const stats = calculateStats(times);

      expect(stats.mean).toBe(100);
      expect(stats.min).toBe(90);
      expect(stats.max).toBe(110);
      expect(stats.runs).toBe(5);
      expect(stats.stddev).toBeCloseTo(7.07, 1);
    });

    it('handles empty array', () => {
      const stats = calculateStats([]);

      expect(stats.mean).toBe(0);
      expect(stats.stddev).toBe(0);
      expect(stats.runs).toBe(0);
    });

    it('handles single value', () => {
      const stats = calculateStats([100]);

      expect(stats.mean).toBe(100);
      expect(stats.stddev).toBe(0);
      expect(stats.min).toBe(100);
      expect(stats.max).toBe(100);
      expect(stats.runs).toBe(1);
    });
  });

  describe('isHighVariance', () => {
    it('returns true for high variance (>20% CV)', () => {
      const stats = calculateStats([50, 100, 150]); // High variance
      expect(isHighVariance(stats)).toBe(true);
    });

    it('returns false for low variance', () => {
      const stats = calculateStats([100, 101, 99, 100, 100]); // Low variance
      expect(isHighVariance(stats)).toBe(false);
    });
  });

  describe('formatTimingStats', () => {
    it('formats stats for display', () => {
      const stats = {
        mean: 100.5,
        stddev: 10.25,
        min: 85,
        max: 115,
        runs: 10,
        coefficientOfVariation: 10.2,
      };

      const formatted = formatTimingStats(stats);
      expect(formatted).toBe('100.50 ± 10.25 ms (10 runs, CV: 10.2%)');
    });
  });
});
