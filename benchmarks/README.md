# ZK-Regex Benchmarks

Benchmarking suite for comparing zk-regex v1 (DFA-based) vs v2 (NFA-based) across Circom and Noir backends.

## Overview

This package measures:
- **R1CS constraint count** (Circom)
- **Gate count** (Noir)
- **Proving time** (Groth16, UltraHonk)
- **Verification time**
- **Memory usage**
- **Scaling behavior** across input lengths

## Prerequisites

Install required tools:

```bash
# Circom (>= 2.1.9)
cargo install circom

# Noir toolchain
curl -L https://raw.githubusercontent.com/noir-lang/noirup/refs/heads/main/install | bash
noirup

# Hyperfine (benchmarking)
brew install hyperfine  # macOS
# or: apt install hyperfine  # Linux

# Yarn (for v1 worktree)
npm install -g yarn
```

## Running Benchmarks

```bash
# Run all benchmarks
bun run bench

# Run specific provider
bun run bench:circom-v1
bun run bench:circom-v2
bun run bench:noir

# Collect and generate outputs
bun run collect
bun run outputs

# Clean results
bun run clean
```

Or from the repository root:

```bash
bun run bench
```

## Output Formats

Results are generated in multiple formats:

- **JSON**: `results/comparison.json` - Machine-readable raw data
- **Markdown**: `outputs/results.md` - Human-readable tables
- **LaTeX**: `outputs/tables.tex` - Academic paper tables

## Patterns Benchmarked

| Pattern | Description | v1 | v2 Circom | v2 Noir |
|---------|-------------|:--:|:---------:|:-------:|
| body_hash | DKIM body hash extraction | ✓ | ✓ | ✓ |
| email_addr | Email address from To header | ✓ | ✓ | ✓ |
| subject_all | Full Subject header | ✓ | ✓ | ✓ |
| simple | `a*b` baseline | - | ✓ | ✓ |

## Input Lengths

Scaling analysis uses: 64, 128, 256, 512 bytes

## Configuration

Edit `config/benchmark.json` to customize:
- Number of runs
- Warmup iterations
- Input lengths
- Patterns to benchmark

## Hardware Requirements

- **RAM**: 8GB minimum, 16GB recommended for 512-byte inputs
- **Disk**: 2GB for Powers of Tau cache

## Reproducing Results

Results include hardware specifications and tool versions for reproducibility:

```bash
cat results/comparison.json | jq '.hardware'
```

## Architecture

```
benchmarks/
  src/
    types.ts           # TypeScript interfaces
    errors.ts          # Error handling
    providers/
      base.ts          # BenchmarkProvider interface
      circom-v1.ts     # v1 Circom metrics
      circom-v2.ts     # v2 Circom metrics
      noir-v2.ts       # v2 Noir metrics
    utils/
      timing.ts        # In-process timing
      hardware.ts      # System info collection
      hyperfine.ts     # Hyperfine wrapper
      worktree.ts      # Git worktree management
      snarkjs.ts       # R1CS info extraction
      ptau.ts          # Powers of Tau caching
  scripts/
    bench.ts           # Main entry point
    collect-results.ts # Aggregate results
    generate-outputs.ts # LaTeX + markdown
  config/
    patterns.json      # Regex patterns
    benchmark.json     # Benchmark settings
```
