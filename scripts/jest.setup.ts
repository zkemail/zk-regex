/**
 * Jest setup file for TypeScript scripts tests
 */

// Increase timeout for integration tests that involve cargo commands
jest.setTimeout(60000);

// Mock process.exit to prevent tests from actually exiting
const mockExit = jest.fn();
jest.spyOn(process, 'exit').mockImplementation(mockExit as never);

// Clear mocks after each test
afterEach(() => {
  jest.clearAllMocks();
});

// Export mock functions for use in tests
export { mockExit };