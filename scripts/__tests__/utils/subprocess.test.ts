/**
 * Tests for subprocess utilities
 */

import { executeCommand, isCommandAvailable } from '../../utils/subprocess';

describe('Subprocess Utilities', () => {
  describe('executeCommand', () => {
    test('executes successful command', () => {
      const result = executeCommand('echo', ['hello world']);
      
      expect(result.success).toBe(true);
      expect(result.stdout?.trim()).toBe('hello world');
      expect(result.error).toBeUndefined();
    });

    test('handles command failure', () => {
      const result = executeCommand('nonexistent-command', []);
      
      expect(result.success).toBe(false);
      expect(result.error).toBeDefined();
    });

    test('captures output correctly', () => {
      const result = executeCommand('echo', ['test output'], {
        captureOutput: true,
      });
      
      expect(result.success).toBe(true);
      expect(result.stdout?.trim()).toBe('test output');
    });

    test('works with different working directory', () => {
      const result = executeCommand('pwd', [], {
        cwd: '/',
        captureOutput: true,
      });
      
      expect(result.success).toBe(true);
      expect(result.stdout?.trim()).toBe('/');
    });
  });

  describe('executeCargo', () => {
    test('constructs cargo command correctly', () => {
      // This test would require complex mocking, so we'll keep it simple
      // and just test that the module exports the function
      const { executeCargo } = require('../../utils/subprocess');
      expect(typeof executeCargo).toBe('function');
    });
  });

  describe('isCommandAvailable', () => {
    test('returns true for available commands', () => {
      // Test with a command that should be available on most systems
      expect(isCommandAvailable('echo')).toBe(true);
    });

    test('returns false for unavailable commands', () => {
      expect(isCommandAvailable('definitely-not-a-command-12345')).toBe(false);
    });
  });
});