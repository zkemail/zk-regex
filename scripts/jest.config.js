/** @type {import('jest').Config} */
export default {
  preset: 'ts-jest/presets/default-esm',
  extensionsToTreatAsEsm: ['.ts'],
  globals: {
    'ts-jest': {
      useESM: true,
    },
  },
  testEnvironment: 'node',
  testMatch: [
    '**/__tests__/**/*.test.ts',
    '**/?(*.)+(spec|test).ts',
  ],
  collectCoverageFrom: [
    'utils/**/*.ts',
    '../circom/scripts/**/*.ts',
    '../noir/scripts/**/*.ts',
    '!**/*.d.ts',
    '!**/node_modules/**',
    '!**/dist/**',
  ],
  moduleNameMapping: {
    '^@utils/(.*)$': '<rootDir>/utils/$1',
    '^@utils$': '<rootDir>/utils/index.ts',
  },
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
};