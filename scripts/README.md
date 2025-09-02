# ZK Regex TypeScript Scripts

This directory contains TypeScript implementations of all ZK Regex build and processing scripts, migrated from Python with enhanced type safety, modern tooling, and improved developer experience.

## Quick Start

```bash
# Install dependencies
yarn install

# Build scripts
yarn build

# Run scripts
yarn gen-regex:circom    # Generate Circom regex circuits
yarn gen-regex:noir      # Generate Noir regex circuits  
yarn gen-inputs:noir     # Generate Noir circuit inputs and tests

# Run tests
yarn test
```

## Scripts Overview

### `circom/scripts/gen-regex.ts`
Generates Circom regex circuits from JSON definitions in `circom/regexes/`.

**Usage**:
```bash
npx tsx ../circom/scripts/gen-regex.ts
```

**What it does**:
- Scans `circom/regexes/` for JSON files
- Converts filenames to PascalCase template names
- Runs zk-regex compiler to generate circuits
- Outputs to `circom/circuits/common/`

### `noir/scripts/gen-regex.ts`  
Generates Noir regex circuits from JSON definitions in `noir/common/`.

**Usage**:
```bash
npx tsx ../noir/scripts/gen-regex.ts
```

**What it does**:
- Processes JSON files in `noir/common/`
- Generates `.nr` circuit files and `.json` graph files
- Handles file naming conversions and cleanup

### `noir/scripts/gen-inputs.ts`
Complex script for generating circuit inputs and Noir test scaffolding.

**Usage**:
```bash
npx tsx ../noir/scripts/gen-inputs.ts
```

**What it does**:
- Phase 1: Generates circuit inputs for pass/fail test cases
- Phase 2: Updates Noir circuit files with test functions
- Handles capture groups, imports, and global constants
- Reports unexpected test results

## Utilities

The `utils/` directory provides shared functionality:

- **`types.ts`**: TypeScript interfaces and type definitions
- **`logger.ts`**: Structured logging with levels
- **`string-utils.ts`**: String manipulation (PascalCase, snake_case)
- **`file-operations.ts`**: Async file I/O operations
- **`subprocess.ts`**: Process execution with error handling

## Development

### Prerequisites

- Node.js >= 18.0.0
- TypeScript 5.0+
- Rust toolchain (for zk-regex compiler)

### Setup

```bash
# Install dependencies
yarn install

# Start development mode with watch
yarn dev

# Build for production
yarn build

# Clean build artifacts  
yarn clean
```

### Testing

```bash
# Run all tests
yarn test

# Run with coverage report
yarn test --coverage

# Watch mode for TDD
yarn test:watch

# Run specific test suite
yarn test utils/string-utils
yarn test integration/gen-regex
```

### Code Quality

The project enforces TypeScript strict mode and includes:

- **Strict type checking**: `strict: true`
- **No unchecked indexed access**: Prevents `undefined` access
- **Exact optional properties**: Stricter object typing
- **Comprehensive error handling**: Custom error types with cause chains
- **Structured logging**: Consistent log formats with context

## Architecture

### Error Handling

All utilities use a consistent error handling pattern:

```typescript
export class ScriptError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'ScriptError';
  }
}

// Usage
try {
  await riskyOperation();
} catch (error) {
  throw new ScriptError('Operation failed', error);
}
```

### Async Operations

Scripts leverage async/await for:

- File I/O operations
- Subprocess execution  
- Parallel processing where beneficial

```typescript
// Parallel file processing
const results = await processFilesParallel(
  jsonFiles, 
  processJsonFile, 
  5 // concurrency limit
);
```

### Type Safety

All data structures are strongly typed:

```typescript
interface SampleData {
  pass: string[];
  fail: string[];
}

interface CircuitInput {
  in_haystack: number[];
  match_start: number;
  match_length: number;
  // ... additional fields
}
```

## Migration Notes

These scripts are direct TypeScript migrations of the original Python versions, maintaining:

- **100% functional compatibility**: Same inputs, same outputs
- **Identical command-line behavior**: Same arguments and exit codes  
- **Same file processing logic**: Identical transformations and validations
- **Compatible with existing tooling**: Works with current cargo builds

**Key improvements over Python versions**:
- Compile-time type checking
- Enhanced error messages with stack traces
- Async operations for better performance
- Comprehensive test coverage
- Modern IDE support with IntelliSense

## Troubleshooting

### Common Issues

**`TypeError: Cannot read property...`**
- Check that all required files exist
- Verify JSON file structure matches expected interfaces

**`Command not found: cargo`**
- Ensure Rust toolchain is installed
- Verify `zk-regex` binary is built: `cargo build --release`

**`Permission denied`**
- Check file permissions on script files
- Ensure output directories are writable

**Tests failing**  
- Run `yarn build` to ensure latest code is compiled
- Check that test environment has required dependencies

### Debug Mode

Enable debug logging:

```bash
DEBUG=* npx tsx script.ts  # All debug output
DEBUG=script:* npx tsx script.ts  # Script-specific debug
```

Or set log level in code:
```typescript
import { Logger, LogLevel } from '../utils/logger.js';
const logger = new Logger(LogLevel.Debug);
```

## Contributing

1. Make changes to TypeScript source files (not compiled JavaScript)
2. Add tests for new functionality
3. Run test suite: `yarn test`
4. Update documentation if needed
5. Build and verify: `yarn build`

### Code Style

- Use TypeScript strict mode
- Prefer `const` over `let`
- Use async/await over Promises
- Add JSDoc comments for public functions
- Handle errors explicitly with custom error types

## Related

- [Migration Documentation](./MIGRATION.md) - Details on Python → TypeScript migration
- [ZK Regex Compiler](../compiler/) - Rust compiler that these scripts invoke  
- [Circom Circuits](../circom/) - Generated Circom circuit outputs
- [Noir Circuits](../noir/) - Generated Noir circuit outputs