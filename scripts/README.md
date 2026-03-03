# ZK Regex TypeScript Scripts

This directory contains TypeScript implementations of all ZK Regex build and processing scripts, migrated from Python with enhanced type safety, modern tooling, and improved developer experience.

Built with **Bun** for blazing-fast performance and seamless TypeScript execution.

## Why Bun?

**Performance Benefits:**
- ⚡ **15-25x faster** dependency installation vs npm/yarn
- 🚀 **Native TypeScript execution** - no transpilation overhead
- 📦 **Built-in bundling** - automatic dependency resolution
- 🏃 **Fast test runner** - 62 tests complete in ~120ms

**Developer Experience:**
- 🔧 **Zero configuration** - works out of the box
- 🎯 **All-in-one tool** - package manager, bundler, runtime, test runner
- 📝 **Built-in TypeScript support** - no need for tsx, ts-node, etc.
- 🛠️ **Modern JavaScript runtime** - supports latest ESNext features

## Quick Start

```bash
# Install dependencies (15-25x faster than npm/yarn)
bun install

# Run scripts (uses built-in TypeScript support)
bun run gen-regex:circom    # Generate Circom regex circuits
bun run gen-regex:noir      # Generate Noir regex circuits  
bun run gen-inputs:noir     # Generate Noir circuit inputs and tests

# Run tests (uses Bun's native test runner)
bun test

# Watch mode for development
bun test --watch
```

## Scripts Overview

### `circom/scripts/gen-regex.ts`
Generates Circom regex circuits from JSON definitions in `circom/regexes/`.

**Usage**:
```bash
bun run ../circom/scripts/gen-regex.ts
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
bun run ../noir/scripts/gen-regex.ts
```

**What it does**:
- Processes JSON files in `noir/common/`
- Generates `.nr` circuit files and `.json` graph files
- Handles file naming conversions and cleanup

### `noir/scripts/gen-inputs.ts`
Complex script for generating circuit inputs and Noir test scaffolding.

**Usage**:
```bash
bun run ../noir/scripts/gen-inputs.ts
```

**What it does**:
- Phase 1: Generates circuit inputs for pass/fail test cases
- Phase 2: Updates Noir circuit files with test functions
- Handles capture groups, imports, and global constants
- Reports unexpected test results

> **⚠️ Important for Manual Tests:**
>
> If you need to add custom/manual tests to Noir circuit files, always add them as **individual test functions**:
>
> ```rust
> #[test]
> fn test_my_custom_case() {
>     // Your test logic here
> }
> ```
>
> **Do NOT** add tests inside `#[cfg(test)] mod tests {}` blocks, as the gen-inputs script will remove these modules during test generation. Individual `#[test]` functions are automatically preserved.

## Utilities

The `utils/` directory provides shared functionality:

- **`types.ts`**: TypeScript interfaces and type definitions
- **`logger.ts`**: Structured logging with levels
- **`string-utils.ts`**: String manipulation (PascalCase, snake_case)
- **`file-operations.ts`**: Async file I/O operations
- **`subprocess.ts`**: Process execution with error handling

## Development

### Prerequisites

- **Bun** >= 1.0.0 ([install guide](https://bun.sh/docs/installation))
- **Node.js** >= 18.0.0 (for compatibility)
- **Rust toolchain** (for zk-regex compiler)

### Setup

```bash
# Install dependencies (super fast with Bun!)
bun install

# All TypeScript execution is handled by Bun automatically
# No separate build step needed for development

# Verify installation
bun run gen-regex:circom --help
```

### Testing

```bash
# Run all tests (62 tests, blazing fast)
bun test

# Watch mode for TDD
bun test --watch

# Run specific test suite
bun test --grep "string-utils"
bun test --grep "gen-regex"

# Verbose output with details
bun test --verbose
```

### Code Quality

The project enforces TypeScript strict mode and includes:

- **Strict type checking**: `strict: true` in TypeScript config
- **No unchecked indexed access**: Prevents `undefined` access errors
- **Exact optional properties**: Stricter object typing
- **Comprehensive error handling**: Custom error types with cause chains
- **Structured logging**: Consistent log formats with context
- **Fast execution**: Bun's optimized TypeScript runtime (no transpilation step)
- **Built-in bundling**: Automatic dependency resolution

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
- **Compile-time type checking** with TypeScript
- **Enhanced error messages** with stack traces  
- **Async operations** for better performance
- **Comprehensive test coverage** (62 tests)
- **Modern IDE support** with IntelliSense
- **Blazing-fast execution** with Bun runtime
- **No build step required** - direct TypeScript execution

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
- Ensure Bun >= 1.0.0 is installed
- Run `bun install` to refresh dependencies
- Check that Rust compiler is available

### Debug Mode

Enable debug logging:

```bash
# Set log level to debug
bun run script.ts  # Built-in debug info with Bun

# Or use environment variable
DEBUG=1 bun run script.ts
```

Or set log level in code:
```typescript
import { Logger, LogLevel } from '../utils/logger.js';
const logger = new Logger(LogLevel.Debug);
```

## Contributing

1. Make changes to TypeScript source files
2. Add tests for new functionality
3. Run test suite: `bun test`
4. Update documentation if needed
5. Verify everything works: `bun run gen-regex:circom`

### Code Style

- Use TypeScript strict mode
- Prefer `const` over `let` 
- Use async/await over Promises
- Add JSDoc comments for public functions
- Handle errors explicitly with custom error types
- Leverage Bun's built-in APIs when available
- Test with `bun test` before committing

## Testing New Regex Patterns

This section explains the complete workflow for testing new regex patterns in both Circom and Noir proving systems.

### Step 1: Create the Regex Configuration

Create a JSON file defining your regex pattern using the decomposed regex format:

**For Circom**: `circom/regexes/<pattern_name>.json`
**For Noir**: `noir/common/regexes/<pattern_name>.json`

```json
{
  "parts": [
    { "Pattern": "prefix:" },
    { "PublicPattern": ["[a-z]+", 32] },
    { "Pattern": ";" }
  ]
}
```

- **`Pattern`**: A literal pattern that must match but is not captured
- **`PublicPattern`**: An array with `[regex_pattern, max_match_length]` - the captured/revealed portion

### Step 2: Create Sample Haystacks (Test Inputs)

Create a JSON file with test inputs:

**For Circom**: `circom/common/sample_haystacks/<pattern_name>.json`
**For Noir**: `noir/common/sample_haystacks/<pattern_name>.json`

```json
{
  "pass": [
    "prefix:hello;",
    "prefix:world;",
    "some text prefix:test; more text"
  ],
  "fail": [
    "prefix:;",
    "PREFIX:hello;",
    "prefix:hello"
  ]
}
```

- **`pass`**: Strings that should match the regex
- **`fail`**: Strings that should NOT match the regex

### Step 3: Build the Compiler

```bash
# Build the release version of the zk-regex compiler
bun run build-release
```

### Step 4: Generate Circuits and Run Tests

#### For Noir

```bash
# 1. Generate Noir circuits from regex definitions
bun run gen-regex:noir

# 2. Generate test inputs AND transform imports (REQUIRED!)
#    This script:
#    - Generates circuit inputs from sample haystacks
#    - Transforms imports from `zkregex::` to `crate::`
#    - Adds test functions to circuit files
bun run gen-inputs:noir

# 3. Run Noir tests
cd noir && nargo test
```

#### For Circom

```bash
# 1. Generate Circom circuits from regex definitions
bun run gen-regex:circom

# 2. Run Circom-specific tests
bun run test:circom
```

### Common Configuration Issues

#### "Invalid substring length" Error
This error occurs when the `max_match_length` in your `PublicPattern` is smaller than the actual matched substring in your test input.

**Solution**: Increase the second value in `PublicPattern`:
```json
{ "PublicPattern": ["[a-z]+", 64] }  // Increase from 32 to 64
```

#### Import Resolution Errors in Noir
If you see `use zkregex::` cannot be resolved errors, you forgot to run:
```bash
bun run gen-inputs:noir
```
This script transforms imports from `zkregex::` to `crate::` for the library context.

#### Missing Module Declarations
When adding new patterns, the `mod.nr` file may need updating. The gen-regex script generates circuit files but doesn't automatically update module declarations.

**Solution**: Add your new module to `noir/src/templates/circuits/mod.nr`:
```rust
pub mod your_new_pattern_regex;
```

### Example: Adding a New Pattern

```bash
# 1. Create regex config
cat > noir/common/regexes/my_pattern.json << 'EOF'
{
  "parts": [
    { "Pattern": "id:" },
    { "PublicPattern": ["[0-9]+", 10] }
  ]
}
EOF

# 2. Create sample haystacks
cat > noir/common/sample_haystacks/my_pattern.json << 'EOF'
{
  "pass": ["id:123", "prefix id:456 suffix"],
  "fail": ["id:", "ID:123", "id:abc"]
}
EOF

# 3. Build compiler
bun run build-release

# 4. Generate and test (Noir)
bun run gen-regex:noir
bun run gen-inputs:noir

# 5. Add module declaration (if needed)
echo 'pub mod my_pattern_regex;' >> noir/src/templates/circuits/mod.nr

# 6. Run tests
cd noir && nargo test
```

## Related

- [Migration Documentation](./MIGRATION.md) - Details on Python → TypeScript migration
- [ZK Regex Compiler](../compiler/) - Rust compiler that these scripts invoke
- [Circom Circuits](../circom/) - Generated Circom circuit outputs
- [Noir Circuits](../noir/) - Generated Noir circuit outputs