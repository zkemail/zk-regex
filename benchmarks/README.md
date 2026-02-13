# ZK-Regex Benchmarks

Benchmarking suite for comparing zk-regex v1 (DFA-based) vs v2 (NFA-based) across Circom and Noir backends.

## Overview

This package measures:
- **R1CS constraint count** (Circom)
- **ACIR opcodes / gate count** (Noir)
- **Proving time** (Groth16 for Circom, UltraHonk for Noir)
- **Verification time**
- **Witness generation time**
- **NFA graph metrics** (states, transitions)

## Prerequisites

Install required tools:

```bash
# Circom (>= 2.1.9)
cargo install circom

# Noir toolchain
curl -L https://raw.githubusercontent.com/noir-lang/noirup/refs/heads/main/install | bash
noirup

# Barretenberg (for Noir proving)
# Installed automatically with nargo, or:
# bbup install

# Hyperfine (optional, for more accurate timing)
brew install hyperfine  # macOS
# or: apt install hyperfine  # Linux

# Node.js (for snarkjs CLI) - via nvm recommended
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 20
```

## Installation

```bash
cd benchmarks
bun install
```

## Running Benchmarks

### Basic Usage

```bash
# Run all benchmarks (all providers, all patterns)
bun run bench

# Or directly:
bun scripts/bench.ts
```

### Filter by Provider

```bash
# Run only Circom v2 (NFA-based, current implementation)
bun run bench:circom-v2

# Run only Circom v1 (DFA-based, main branch via worktree)
bun run bench:circom-v1

# Run only Noir v2
bun run bench:noir
```

### Filter by Pattern

```bash
# Run specific pattern
bun scripts/bench.ts --pattern simple_regex
bun scripts/bench.ts --pattern body_hash
bun scripts/bench.ts --pattern email_addr
bun scripts/bench.ts --pattern subject_all

# Combine provider and pattern filters
bun scripts/bench.ts --provider circom-v2 --pattern simple_regex
```

### Available Patterns

| Pattern | Name in CLI | Description | Capture Groups | v1 Support |
|---------|-------------|-------------|:--------------:|:----------:|
| `simple` | `simple` or `simple_regex` | `a*b` baseline | No | No |
| `body_hash` | `body_hash` | DKIM body hash extraction | Yes | Yes |
| `email_addr` | `email_addr` | Email address from To header | Yes | Yes |
| `subject_all` | `subject_all` | Full Subject header | Yes | Yes |

## Configuration

Edit `config/benchmark.json` to customize:

```json
{
  "config": {
    "warmupRuns": 3,
    "minRuns": 10,
    "inputLengths": [64, 128, 256]
  }
}
```

### Input Lengths

The default input lengths are `[64, 128, 256]` bytes. Larger inputs require larger Powers of Tau files:

| Input Size | Approx. Constraints (simple) | Required ptau |
|------------|------------------------------|---------------|
| 64-256 bytes | ~41K | pot16 (65K max) |
| 512 bytes | ~70K | pot17 (131K max) |

### Powers of Tau

The benchmark automatically downloads a Powers of Tau file on first run. The default is `pot16` (~76MB).

To use larger circuits, edit `src/utils/ptau.ts`:

```typescript
// For pot17 (supports up to 131K constraints):
const PTAU_URL = 'https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_17.ptau';
```

Available sizes:
| ptau | Max Constraints | File Size |
|------|-----------------|-----------|
| pot15 | 32K | ~38MB |
| pot16 | 65K | ~76MB |
| pot17 | 131K | ~151MB |
| pot18 | 262K | ~302MB |
| pot19 | 524K | ~604MB |
| pot20 | 1M | ~1.1GB |

## Output

Currently outputs to console. Example output:

```
  Benchmarking simple...
    Input length: 64 bytes
    NFA: 5 states, 6 transitions
    Compiling simple_regex...
    Constraints: 41096
    Setting up Groth16...
    Measuring witness generation (10 runs)...
    Measuring proof generation...
    Measuring verification (10 runs)...
      Done (placeholder metrics)
```

### Planned Output Formats

- **JSON**: `results/comparison.json` - Machine-readable raw data
- **Markdown**: `outputs/results.md` - Human-readable tables
- **LaTeX**: `outputs/tables.tex` - Academic paper tables

## Providers

### circom-v2 (default)
Benchmarks the current NFA-based v2 implementation in `circom/circuits/common/`.

### circom-v1
Sets up a git worktree from the `main` branch to benchmark the legacy DFA-based implementation. Requires the pattern to have `availableInV1: true` in `config/patterns.json`.

### noir-v2
Benchmarks Noir circuits in `noir/src/templates/` using nargo and Barretenberg's UltraHonk prover.

## Troubleshooting

### "Constraint count exceeds ptau limit"
The circuit has more constraints than the Powers of Tau file supports. Either:
1. Reduce `inputLengths` in `config/benchmark.json`
2. Use a larger ptau file (see Powers of Tau section above)

### "npx: command not found"
Node.js isn't in PATH. The benchmark uses snarkjs CLI which requires Node.js. Ensure nvm is properly configured.

### "Hyperfine failed, using in-process measurement"
Hyperfine isn't installed or available. The benchmark will fall back to in-process timing, which is less accurate but functional.

### Slow first run
The first run downloads the Powers of Tau file and generates zkey files for each circuit. Subsequent runs use cached files and are much faster.

## Architecture

```
benchmarks/
  src/
    types.ts           # TypeScript interfaces
    errors.ts          # Error handling (Result type)
    providers/
      base.ts          # BenchmarkProvider interface
      circom-v1.ts     # v1 DFA-based metrics
      circom-v2.ts     # v2 NFA-based metrics
      noir-v2.ts       # v2 Noir metrics
    utils/
      timing.ts        # In-process timing utilities
      hardware.ts      # System info collection
      hyperfine.ts     # Hyperfine CLI wrapper
      worktree.ts      # Git worktree for v1
      snarkjs.ts       # snarkjs CLI wrapper
      ptau.ts          # Powers of Tau download/cache
  scripts/
    bench.ts           # Main entry point
  config/
    patterns.json      # Regex pattern definitions
    benchmark.json     # Benchmark settings
```

## Memory Profiling

The benchmark suite measures peak memory (RSS) for each phase using `/usr/bin/time`.

### Measured Phases

| Provider | Phases |
|----------|--------|
| Circom v1 | compile, witnessGen, prove, verify |
| Circom v2 | compile, witnessGen, prove, verify |
| Noir v2 | compile, witnessGen, prove, verify |

Note: Noir's `nargo execute` command is labeled as `witnessGen` for cross-framework consistency, as it performs the same function as Circom's witness generation step.

### Platform Support

- **macOS**: Uses BSD `time -l` (reports bytes)
- **Linux**: Uses GNU `time -v` (reports kilobytes)
- **Windows**: Memory profiling not supported (timing only)

### CLI Options

```bash
# Run benchmarks with memory profiling (default)
bun run bench

# Disable memory profiling
bun run bench --no-memory
```

### Memory Output

Memory measurements are displayed inline with timing results:

```
Witness gen: 156ms (±12) | Memory: 85MB (±2)
Prove: 2340ms (±45) | Memory: 512MB (±8)
Verify: 45ms (±3) | Memory: 45MB (±1)
```

Memory data is included in:
- `results/comparison.json` - Per-phase memory stats
- `outputs/results.md` - Memory tables in Markdown
- `outputs/tables.tex` - Memory tables in LaTeX

### Memory Requirements

Large input benchmarks may require significant RAM:

| Input Size | Approx. Prove Memory (Circom) |
|------------|-------------------------------|
| 64 bytes | ~500 MB |
| 128 bytes | ~1 GB |
| 256 bytes | ~2 GB |
| 512 bytes | ~4 GB |

If benchmarks fail with memory errors, either:
1. Reduce `inputLengths` in `config/benchmark.json`
2. Run with `--no-memory` to skip memory profiling overhead

## Hardware Requirements

- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 500MB - 2GB for Powers of Tau cache (depending on ptau size)
