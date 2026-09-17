/**
 * Tests for file operation utilities
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { tmpdir } from 'os';
import {
  ensureDirectory,
  readJsonFile,
  writeJsonFile,
  readTextFile,
  writeTextFile,
  fileExists,
  directoryExists,
  listFilesWithExtension,
  moveFile,
  removeFile,
  removeDirectory,
} from '../../utils/file-operations';

describe('File Operations', () => {
  let testDir: string;

  beforeEach(async () => {
    testDir = path.join(tmpdir(), `zk-regex-test-${Date.now()}`);
    await fs.mkdir(testDir, { recursive: true });
  });

  afterEach(async () => {
    try {
      await fs.rm(testDir, { recursive: true });
    } catch {
      // Ignore cleanup errors
    }
  });

  describe('ensureDirectory', () => {
    test('creates directory if it does not exist', async () => {
      const newDir = path.join(testDir, 'new-directory');
      await ensureDirectory(newDir);
      
      expect(await directoryExists(newDir)).toBe(true);
    });

    test('does nothing if directory already exists', async () => {
      await ensureDirectory(testDir);
      expect(await directoryExists(testDir)).toBe(true);
    });
  });

  describe('JSON file operations', () => {
    test('writeJsonFile and readJsonFile work correctly', async () => {
      const filePath = path.join(testDir, 'test.json');
      const testData = { name: 'test', value: 42, nested: { prop: 'value' } };

      await writeJsonFile(filePath, testData);
      const readData = await readJsonFile(filePath);

      expect(readData).toEqual(testData);
    });

    test('readJsonFile throws on invalid JSON', async () => {
      const filePath = path.join(testDir, 'invalid.json');
      await fs.writeFile(filePath, 'invalid json');

      await expect(readJsonFile(filePath)).rejects.toThrow();
    });
  });

  describe('Text file operations', () => {
    test('writeTextFile and readTextFile work correctly', async () => {
      const filePath = path.join(testDir, 'test.txt');
      const testContent = 'Hello, World!\nThis is a test file.';

      await writeTextFile(filePath, testContent);
      const readContent = await readTextFile(filePath);

      expect(readContent).toBe(testContent);
    });
  });

  describe('File existence checks', () => {
    test('fileExists returns true for existing files', async () => {
      const filePath = path.join(testDir, 'exists.txt');
      await fs.writeFile(filePath, 'content');

      expect(await fileExists(filePath)).toBe(true);
    });

    test('fileExists returns false for non-existing files', async () => {
      const filePath = path.join(testDir, 'does-not-exist.txt');
      expect(await fileExists(filePath)).toBe(false);
    });

    test('directoryExists returns true for existing directories', async () => {
      expect(await directoryExists(testDir)).toBe(true);
    });

    test('directoryExists returns false for non-existing directories', async () => {
      const dirPath = path.join(testDir, 'does-not-exist');
      expect(await directoryExists(dirPath)).toBe(false);
    });
  });

  describe('listFilesWithExtension', () => {
    test('lists files with specified extension', async () => {
      await fs.writeFile(path.join(testDir, 'file1.json'), '{}');
      await fs.writeFile(path.join(testDir, 'file2.json'), '{}');
      await fs.writeFile(path.join(testDir, 'file3.txt'), 'text');

      const jsonFiles = await listFilesWithExtension(testDir, '.json');
      
      expect(jsonFiles).toHaveLength(2);
      expect(jsonFiles).toContain('file1.json');
      expect(jsonFiles).toContain('file2.json');
      expect(jsonFiles).not.toContain('file3.txt');
    });

    test('returns empty array when no files match', async () => {
      await fs.writeFile(path.join(testDir, 'file.txt'), 'text');

      const jsonFiles = await listFilesWithExtension(testDir, '.json');
      
      expect(jsonFiles).toHaveLength(0);
    });
  });

  describe('moveFile', () => {
    test('moves file successfully', async () => {
      const srcPath = path.join(testDir, 'source.txt');
      const destPath = path.join(testDir, 'destination.txt');
      const content = 'test content';

      await fs.writeFile(srcPath, content);
      await moveFile(srcPath, destPath);

      expect(await fileExists(srcPath)).toBe(false);
      expect(await fileExists(destPath)).toBe(true);
      expect(await readTextFile(destPath)).toBe(content);
    });
  });

  describe('removeFile', () => {
    test('removes file successfully', async () => {
      const filePath = path.join(testDir, 'to-remove.txt');
      await fs.writeFile(filePath, 'content');

      await removeFile(filePath);

      expect(await fileExists(filePath)).toBe(false);
    });
  });

  describe('removeDirectory', () => {
    test('removes directory and contents', async () => {
      const dirPath = path.join(testDir, 'to-remove');
      await fs.mkdir(dirPath);
      await fs.writeFile(path.join(dirPath, 'file.txt'), 'content');

      await removeDirectory(dirPath);

      expect(await directoryExists(dirPath)).toBe(false);
    });
  });
});