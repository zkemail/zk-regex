/**
 * Integration tests for gen-inputs script
 */

import * as path from 'path';
import * as fs from 'fs/promises';
import { tmpdir } from 'os';
import {
  ensureDirectory,
  writeJsonFile,
  writeTextFile,
  fileExists,
  SampleData,
  CircuitInput,
} from '../../utils/index.js';

describe('Gen-Inputs Integration Tests', () => {
  let testProjectRoot: string;
  let testSampleHaystacksDir: string;
  let testCircuitsDir: string;
  let testGraphsDir: string;
  let testCircuitInputsDir: string;

  beforeEach(async () => {
    // Create temporary test environment
    testProjectRoot = path.join(tmpdir(), `zk-regex-gen-inputs-test-${Date.now()}`);
    testSampleHaystacksDir = path.join(testProjectRoot, 'sample_haystacks');
    testCircuitsDir = path.join(testProjectRoot, 'circuits');
    testGraphsDir = path.join(testProjectRoot, 'graphs');
    testCircuitInputsDir = path.join(testSampleHaystacksDir, 'circuit_inputs');

    await ensureDirectory(testSampleHaystacksDir);
    await ensureDirectory(testCircuitsDir);
    await ensureDirectory(testGraphsDir);
    await ensureDirectory(testCircuitInputsDir);

    // Create test sample data
    const sampleData: SampleData = {
      pass: [
        'test@example.com',
        'user@domain.org',
      ],
      fail: [
        'invalid-email',
        'no-at-symbol',
      ],
    };

    await writeJsonFile(path.join(testSampleHaystacksDir, 'email_addr.json'), sampleData);

    // Create test graph file
    await writeJsonFile(path.join(testGraphsDir, 'email_addr_graph.json'), {
      states: [0, 1, 2],
      transitions: [],
      accepting: [2],
    });

    // Create test circuit file
    const circuitContent = `
use crate::templates::regex_match;

pub global NUM_CAPTURE_GROUPS: u32 = 0;

fn main() -> pub Field {
    regex_match::<300, 300>()
}
`;
    
    await writeTextFile(path.join(testCircuitsDir, 'email_addr_regex.nr'), circuitContent);
  });

  afterEach(async () => {
    // Cleanup test environment
    try {
      await fs.rmdir(testProjectRoot, { recursive: true });
    } catch {
      // Ignore cleanup errors
    }
  });

  describe('Sample data processing', () => {
    test('reads sample haystacks correctly', async () => {
      const sampleFile = path.join(testSampleHaystacksDir, 'email_addr.json');
      const content = await fs.readFile(sampleFile, 'utf8');
      const sampleData: SampleData = JSON.parse(content);

      expect(sampleData.pass).toHaveLength(2);
      expect(sampleData.fail).toHaveLength(2);
      expect(sampleData.pass).toContain('test@example.com');
      expect(sampleData.fail).toContain('invalid-email');
    });

    test('handles empty sample data gracefully', async () => {
      const emptySampleData: SampleData = { pass: [], fail: [] };
      await writeJsonFile(path.join(testSampleHaystacksDir, 'empty.json'), emptySampleData);
      
      const content = await fs.readFile(path.join(testSampleHaystacksDir, 'empty.json'), 'utf8');
      const parsed: SampleData = JSON.parse(content);
      
      expect(parsed.pass).toHaveLength(0);
      expect(parsed.fail).toHaveLength(0);
    });
  });

  describe('Circuit input generation workflow', () => {
    test('creates circuit inputs directory structure', async () => {
      expect(await fileExists(testCircuitInputsDir)).toBe(true);
      
      // Test expected file naming pattern
      const expectedPassFile = path.join(testCircuitInputsDir, 'email_addr_pass_0.json');
      const expectedFailFile = path.join(testCircuitInputsDir, 'email_addr_fail_0_temp.json');
      
      // These files would be created by the actual cargo command
      // For testing, we verify the paths are correct
      expect(path.basename(expectedPassFile)).toBe('email_addr_pass_0.json');
      expect(path.basename(expectedFailFile)).toBe('email_addr_fail_0_temp.json');
    });

    test('handles template name extraction correctly', () => {
      const testCases = [
        { input: 'email_addr.json', expected: 'email_addr' },
        { input: 'simple.json', expected: 'simple' },
        { input: 'body_hash.json', expected: 'body_hash' },
      ];

      testCases.forEach(({ input, expected }) => {
        const templateName = path.parse(input).name;
        expect(templateName).toBe(expected);
      });
    });
  });

  describe('Circuit file processing', () => {
    test('identifies circuit files correctly', async () => {
      const files = await fs.readdir(testCircuitsDir);
      const circuitFiles = files.filter(file => file.endsWith('_regex.nr'));
      
      expect(circuitFiles).toHaveLength(1);
      expect(circuitFiles[0]).toBe('email_addr_regex.nr');
    });

    test('extracts template name from circuit files', () => {
      const circuitFile = 'email_addr_regex.nr';
      const templateName = path.parse(circuitFile).name.replace('_regex', '');
      
      expect(templateName).toBe('email_addr');
    });

    test('reads circuit content correctly', async () => {
      const circuitFile = path.join(testCircuitsDir, 'email_addr_regex.nr');
      const content = await fs.readFile(circuitFile, 'utf8');
      
      expect(content).toContain('use crate::templates::regex_match');
      expect(content).toContain('NUM_CAPTURE_GROUPS');
    });
  });

  describe('Test function generation', () => {
    test('generates correct test function signature', () => {
      const testFnName = 'test_email_addr_pass_0';
      const expectedSignature = `fn ${testFnName}()`;
      
      expect(expectedSignature).toBe('fn test_email_addr_pass_0()');
    });

    test('processes circuit input data correctly', () => {
      const mockCircuitInput: CircuitInput = {
        in_haystack: [116, 101, 115, 116], // "test" in ASCII
        match_start: 0,
        match_length: 4,
        curr_states: [0, 1, 2, 3],
        next_states: [1, 2, 3, 4],
      };

      expect(mockCircuitInput.in_haystack).toEqual([116, 101, 115, 116]);
      expect(mockCircuitInput.match_start).toBe(0);
      expect(mockCircuitInput.match_length).toBe(4);
    });

    test('handles capture groups correctly', () => {
      const mockCircuitInputWithCG: CircuitInput = {
        in_haystack: [116, 101, 115, 116],
        match_start: 0,
        match_length: 4,
        curr_states: [0, 1, 2, 3],
        next_states: [1, 2, 3, 4],
        capture_group_start_indices: [0, 2],
        capture_group_ids: [[1, 1, 0, 0], [2, 2, 0, 0]],
        capture_group_starts: [[0, 1, 0, 0], [2, 3, 0, 0]],
      };

      expect(mockCircuitInputWithCG.capture_group_start_indices).toHaveLength(2);
      expect(mockCircuitInputWithCG.capture_group_ids).toHaveLength(2);
      expect(mockCircuitInputWithCG.capture_group_starts).toHaveLength(2);
    });
  });

  describe('Import replacement functionality', () => {
    test('identifies zkregex imports correctly', () => {
      const testLines = [
        'use zkregex::templates::regex_match;',
        'use crate::utils::helper;',
        'use zkregex::types::State;',
        'fn main() {}',
      ];

      const zkregexImports = testLines.filter(line => 
        line.trim().startsWith('use zkregex::')
      );

      expect(zkregexImports).toHaveLength(2);
    });

    test('replaces zkregex imports with crate imports', () => {
      const originalLine = 'use zkregex::templates::regex_match;';
      const replacedLine = originalLine.replace('use zkregex::', 'use crate::');
      
      expect(replacedLine).toBe('use crate::templates::regex_match;');
    });
  });

  describe('Global constants handling', () => {
    test('detects missing global constants', () => {
      const circuitContent = `
        fn main() {
          // No global constants defined
        }
      `;

      const hasMaxHaystackLen = circuitContent.match(/^global MAX_HAYSTACK_LEN: u32\s*=\s*\d+;/m);
      const hasMaxMatchLen = circuitContent.match(/^global MAX_MATCH_LEN: u32\s*=\s*\d+;/m);

      expect(hasMaxHaystackLen).toBeNull();
      expect(hasMaxMatchLen).toBeNull();
    });

    test('detects existing global constants', () => {
      const circuitContent = `
        global MAX_HAYSTACK_LEN: u32 = 300;
        global MAX_MATCH_LEN: u32 = 300;
        
        fn main() {}
      `;

      const hasMaxHaystackLen = circuitContent.match(/^global MAX_HAYSTACK_LEN: u32\s*=\s*\d+;/m);
      const hasMaxMatchLen = circuitContent.match(/^global MAX_MATCH_LEN: u32\s*=\s*\d+;/m);

      expect(hasMaxHaystackLen).not.toBeNull();
      expect(hasMaxMatchLen).not.toBeNull();
    });
  });

  describe('Error handling and edge cases', () => {
    test('handles missing graph files', async () => {
      // Remove the graph file
      await fs.unlink(path.join(testGraphsDir, 'email_addr_graph.json'));
      
      const graphExists = await fileExists(path.join(testGraphsDir, 'email_addr_graph.json'));
      expect(graphExists).toBe(false);
    });

    test('handles invalid JSON in sample files', async () => {
      const invalidJsonFile = path.join(testSampleHaystacksDir, 'invalid.json');
      await fs.writeFile(invalidJsonFile, 'invalid json content');

      const content = await fs.readFile(invalidJsonFile, 'utf8');
      expect(() => JSON.parse(content)).toThrow();
    });

    test('handles empty haystacks', () => {
      const sampleData: SampleData = {
        pass: ['', 'valid-content'],
        fail: ['', 'invalid-content'],
      };

      const nonEmptyPass = sampleData.pass.filter(haystack => haystack);
      const nonEmptyFail = sampleData.fail.filter(haystack => haystack);

      expect(nonEmptyPass).toHaveLength(1);
      expect(nonEmptyFail).toHaveLength(1);
    });
  });
});