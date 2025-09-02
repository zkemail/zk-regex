/**
 * Tests for subprocess utilities
 */

import { executeCommand, executeCargo, isCommandAvailable } from '../../utils/subprocess.js';

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
      const result = executeCommand('echo', ['-n', 'test output'], {
        captureOutput: true,
      });
      
      expect(result.success).toBe(true);
      expect(result.stdout).toBe('test output');
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
      // Mock the cargo command to avoid dependency on actual cargo
      const originalExecuteCommand = require('../../utils/subprocess.js').executeCommand;
      let capturedCommand: string;
      let capturedArgs: string[];

      jest.doMock('../../utils/subprocess.js', () => ({
        ...jest.requireActual('../../utils/subprocess.js'),
        executeCommand: jest.fn((command: string, args: string[]) => {
          capturedCommand = command;
          capturedArgs = args;
          return { success: true };
        }),
      }));

      const { executeCargo: mockedExecuteCargo } = require('../../utils/subprocess.js');
      
      mockedExecuteCargo('build', ['--release'], { quiet: true });

      expect(capturedCommand).toBe('cargo');
      expect(capturedArgs).toEqual(['build', '--quiet', '--release']);
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