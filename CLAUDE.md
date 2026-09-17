# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**zk-regex** is a compiler that converts regular expressions into zero-knowledge circuit code for **Circom** and **Noir** proving systems. It enables proving regex matching within ZK circuits without revealing the matched text.

The compiler parses regex patterns, builds circuit-friendly Non-deterministic Finite Automata (NFAs) using Rust's `regex-automata` crate, and generates verifiable circuit code.

## Project Structure

This is a **multi-language monorepo** with Bun workspaces:

- **`compiler/`** - Core Rust library (also compiled to WASM)
  - Parses regex patterns and builds NFAs
  - Generates circuit code for Circom and Noir
  - Exposes both native Rust API and WASM bindings
  - Binary: `zk-regex` CLI tool at `compiler/src/bin/zk-regex.rs`

- **`circom/`** - Circom integration package
  - Helper templates and circuits required by generated code
  - Test suite for generated Circom circuits
  - Requires **Circom >= 2.1.9**

- **`noir/`** - Noir integration package
  - Helper libraries for generated Noir circuits
  - Test inputs generation

- **`scripts/`** - TypeScript utilities and code generation
  - Circuit generation scripts (`gen-regex:circom`, `gen-regex:noir`)
  - Input generation for tests
  - Jest test suite

## Common Commands

### Building

```bash
# Build Rust compiler and WASM bindings (development)
bun run build

# Build optimized release version
bun run build-release

# Build for specific targets
cd compiler
cargo build                  # Native Rust library
cargo build --release        # Optimized native build
wasm-pack build --target nodejs  # WASM for Node.js
```

### Testing

```bash
# Run all tests (30s timeout configured)
bun test

# Run specific test suites
bun run test:scripts         # TypeScript tests only
bun run test:circom          # Circom circuit tests only

# Rust tests
cd compiler
cargo test                   # Native Rust tests
wasm-pack test --node        # WASM tests
```

### Code Generation

```bash
# Generate Circom templates from regex definitions
bun run gen-regex:circom

# Generate Noir templates from regex definitions
bun run gen-regex:noir

# Generate Noir test inputs
bun run gen-inputs:noir
```

### Git Hooks

```bash
# Install git hooks (automatic via postinstall)
bun run install-hooks
```

## Architecture

### Compilation Pipeline

1. **Regex Parsing** (`compiler/src/`)
   - Input: Standard regex pattern
   - Uses `regex-automata` to build Thompson NFA
   - Applies optimization passes to make circuit-friendly

2. **Circuit Generation** (`compiler/src/backend/`)
   - Converts NFA to circuit representation
   - Framework-specific code generation:
     - **Circom**: Template-based circuits with state machines
     - **Noir**: Function-based verification logic

3. **Input Generation** (`compiler/src/`)
   - `gen_circuit_inputs()` creates prover inputs
   - Formats vary by proving framework (Circom vs Noir)
   - Returns `ProverInputs` enum with framework-specific data

### Key Types

- **`NFAGraph`** - Internal NFA representation
- **`ProvingFramework`** - Enum for Circom/Noir target selection
- **`DecomposedRegexConfig`** - Complex regex patterns built from parts
- **`RegexPart`** - Pattern component (normal or public pattern)
- **`ProverInputs`** - Framework-specific prover inputs (Circom/Noir)
- **`CompilerError`** - Structured errors with error codes

### WASM Bindings

The compiler is compiled to WASM for use in TypeScript/JavaScript environments:
- Built with `wasm-pack`
- Targets: Node.js (`pkg/`) and Web (`pkg-web/`)
- Same API as native Rust, accessible from TypeScript

## Critical Development Patterns

### Pre-push Hook for Template Sync

A **pre-push git hook** ensures generated templates stay synchronized with compiler changes:

- **Automatically installed** via `bun install` (runs `postinstall` script)
- **Scans commits** being pushed for changes to `compiler/src/`
- **Regenerates templates** if compiler modified:
  1. Builds release compiler: `bun run build-release`
  2. Regenerates Circom: `bun run gen-regex:circom`
  3. Regenerates Noir: `bun run gen-regex:noir`
  4. Validates templates match committed versions
- **Blocks push** if templates outdated

**If push is blocked:**
```bash
git diff circom/circuits/ noir/src/templates/
git add circom/circuits/ noir/src/templates/
git commit -m "chore: regenerate templates after compiler changes"
git push
```

**Emergency bypass** (use sparingly):
```bash
git push --no-verify
```

### Adding Test Cases

To add new test cases for regex patterns:

1. Add test inputs to the appropriate sample haystacks file in `noir/common/sample_haystacks/<regex_name>.json` or `circom/common/sample_haystacks/<regex_name>.json`
2. Run the input generation script: `bun run gen-inputs:noir` or `bun run gen-inputs:circom`
3. Tests will be automatically generated from your sample data

All tests are fully reproducible from the source definitions and should not be manually written in circuit files.

## Version Requirements

- **Bun**: >= 1.0.0 (pinned to 1.2.22 in CI)
- **Node.js**: >= 18.0.0
- **Rust**: Latest stable (2024 edition)
- **Circom**: >= 2.1.9 (must install from source)
- **Cargo tools**: `wasm-pack` for WASM builds

### Installing Circom 2.1.9

```bash
# Install Rust first if needed
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
source ~/.cargo/env

# Install Circom from source (official method)
git clone https://github.com/iden3/circom.git
cd circom
git checkout v2.1.9
cargo build --release
cargo install --path circom

# Verify
circom --help  # Should show >= 2.1.9
```

## Workspace Configuration

Uses **Bun workspaces** defined in root `package.json`:
- `scripts/` - TypeScript utilities
- `circom/` - Circom integration
- `compiler/` - Rust/WASM package

Rust workspace defined in root `Cargo.toml`:
- `compiler/` - Main compiler crate

Shared dependencies managed via workspace inheritance in `Cargo.toml`.

## Testing Configuration

- **Timeout**: 30 seconds globally (`bunfig.toml`)
- **Test runner**: Jest for TypeScript, Cargo for Rust
- **CI**: GitHub Actions with Bun 1.2.22, Ubuntu latest
- **Circom tests**: Require compiled circuits and circom binary

## API Entry Points

### Rust API (`compiler/src/lib.rs`)

```rust
// Compile regex to NFA
pub fn compile(pattern: &str) -> CompilerResult<NFAGraph>

// Generate circuit from raw regex
pub fn gen_from_raw(
    pattern: &str,
    max_bytes: Option<Vec<usize>>,
    template_name: &str,
    proving_framework: ProvingFramework,
) -> CompilerResult<(NFAGraph, String)>

// Generate circuit from decomposed config
pub fn gen_from_decomposed(
    config: DecomposedRegexConfig,
    template_name: &str,
    proving_framework: ProvingFramework,
) -> CompilerResult<(NFAGraph, String)>

// Generate prover inputs
pub fn gen_circuit_inputs(
    nfa: &NFAGraph,
    input: &str,
    max_haystack_len: usize,
    max_match_len: usize,
    proving_framework: ProvingFramework,
) -> CompilerResult<ProverInputs>
```

### WASM API (TypeScript)

Same functions exposed via WASM bindings in `compiler/src/wasm.rs`, consumable from TypeScript after building with `wasm-pack`.

## Error Handling

Structured error system with error codes:
- **E1001**: Invalid regex syntax
- **E1002**: Unsupported regex features
- **E3002**: Invalid capture group configuration
- **E5001**: Invalid configuration parameters

All errors use `CompilerError` enum with descriptive messages and error codes for debugging.
