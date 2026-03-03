
# ZK-Regex: Verifiable Regular Expressions in Arithmetic Circuits

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.15603470.svg)](https://doi.org/10.5281/zenodo.15603470)

`zk-regex` enables proving regular expression matching within zero-knowledge circuits. It compiles standard regex patterns into circuit-friendly Non-deterministic Finite Automata (NFAs) and generates corresponding circuit code for **[Circom](https://docs.circom.io/)** and **[Noir](https://noir-lang.org/)** proving systems.

This allows developers to build ZK applications that can verifiably process or validate text based on complex patterns without revealing the text itself.

## Key Features

-   **Regex Compilation:** Converts standard regular expression syntax into NFAs optimized for ZK circuits.
-   **Circuit Generation:** Automatically generates verifiable circuit code for:
    -   [Circom](https://docs.circom.io/)
    -   [Noir](https://noir-lang.org/)
-   **Helper Libraries:** Provides supporting libraries and circuit templates for easier integration into Circom and Noir projects.
-   **Underlying Tech:** Leverages the robust Thompson NFA construction via the Rust [`regex-automata`](https://github.com/rust-lang/regex/tree/master/regex-automata) crate.

## Project Structure

The project is organized into the following packages:

-   **`compiler/`**: The core Rust library responsible for parsing regex patterns, building NFAs, and generating circuit code. See [compiler/README.md](./compiler/README.md) for API details and usage.
-   **`circom/`**: Contains Circom templates and helper circuits required to use the generated regex verification circuits within a Circom project. See [circom/README.md](./circom/README.md) for integration details.
-   **`noir/`**: Contains Noir contracts/libraries required to use the generated regex verification logic within a Noir project. See [noir/README.md](./noir/README.md) for integration details.

## High-Level Workflow

1.  **Define Regex:** Start with your standard regular expression pattern.
    ```json
    {
        "parts": [
            { "Pattern": "(?:\r\n|^)subject:" },
            { "PublicPattern": ["[a-z]+", 128] },
            { "Pattern": "\r\n" }
        ]
    }
    ```
2.  **Compile & Generate Circuit:** Use the `zk-regex-compiler` library to compile the pattern and generate circuit code for your chosen framework (Circom or Noir).

    ```rust
    // Simplified example - see compiler/README.md for full usage
    use zk_regex_compiler::{gen_from_raw, ProvingFramework};

    let parts = Vec::new();
    parts.push(RegexPart::Pattern("(?:\\r\\n|^)subject:".to_string()));
    parts.push(RegexPart::PublicPattern(("([a-z]+)".to_string(), 128)));
    parts.push(RegexPart::Pattern("\r\n".to_string()));
    let decomposed_config = DecomposedRegexConfig { parts };

    let (nfa, circom_code) = gen_from_decomposed(parts, "MyRegex", ProvingFramework::Circom)?;
    // Save or use circom_code
    ```

3.  **Integrate Circuit:** Include the generated code and the corresponding helper library ([`zk-regex-circom`](./circom/README.md) or [`zk-regex-noir`](./noir/README.md)) in your ZK project.
4.  **Generate Inputs:** Use the `zk-regex-compiler`'s [`gen_circuit_inputs`](./compiler/README.md#gen_circuit_inputsnfa-nfagraph-input-str-max_haystack_len-usize-max_match_len-usize-proving_framework-provingframework---resultproverinputs-compilererror) function to prepare the private and public inputs for your prover based on the text you want to match.
5.  **Prove & Verify:** Run your ZK proving system using the generated inputs and circuit. The proof demonstrates that the (private) text matches the (public) regex pattern.

## Installation

### Prerequisites
- **Node.js** >= 18.0.0
- **Bun** >= 1.0.0 (for package management and TypeScript execution)
- **Rust & Cargo** (for the core compiler and Circom installation)
- **Circom** >= 2.1.9 (for circuit compilation)

### Quick Setup
```bash
# Install Bun if you haven't already
curl -fsSL https://bun.sh/install | bash

# Install Rust (required for Circom)
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
source ~/.cargo/env

# Install Circom from source (required for circuit compilation)
git clone https://github.com/iden3/circom.git
cd circom
cargo build --release
cargo install --path circom
cd ..

# Verify circom installation
circom --help  # Should show version >= 2.1.9

# Clone and setup the ZK-Regex repository
git clone https://github.com/zkemail/zk-regex.git
cd zk-regex
bun install

# Build the Rust compiler
bun run build-release
```

### Component-Specific Installation
-   **Compiler:** If using the compiler directly in a Rust project, add it to your `Cargo.toml`. See [compiler/README.md](./compiler/README.md).
-   **Circom Helpers:** See [circom/README.md](./circom/README.md) for instructions on integrating the Circom templates.
-   **Noir Helpers:** See [noir/README.md](./noir/README.md) for instructions on adding the Noir library dependency.

## Development

### Common Commands

```bash
# Install all dependencies
bun install

# Generate Circom circuits
bun run gen-regex:circom

# Generate Noir circuits  
bun run gen-regex:noir

# Generate Noir test inputs
bun run gen-inputs:noir

# Run tests
bun run test

# Build compiler (development)
bun run build

# Build compiler (optimized release)
bun run build-release
```

## Contributing

Contributions are welcome! This project uses **Bun** for package management and TypeScript execution. Please follow these practices:

1. **Setup:** Ensure you have Bun >= 1.0.0 installed
2. **Dependencies:** Run `bun install` after cloning (this automatically installs git hooks)
3. **Testing:** Run `bun test` before submitting PRs
4. **Code Style:** Follow existing TypeScript and Rust conventions

### Automatic Template Generation

This project includes a **pre-push git hook** that ensures Circom and Noir templates are automatically regenerated when compiler changes are made:

- **Automatic Setup**: The hook installs automatically when you run `bun install`
- **What it does**: Detects compiler changes and regenerates templates before push
- **Blocks pushes**: Prevents pushing if templates are outdated
- **Team-wide**: All contributors get the same protection automatically

**How it works:**
1. Scans commits being pushed for modifications to `compiler/src/` files
2. Builds compiler with `bun run build-release` 
3. Regenerates both `bun run gen-regex:circom` and `bun run gen-regex:noir`
4. Validates that generated templates match committed versions
5. Blocks push if templates need updates but aren't committed

**If your push is blocked:**
```bash
# Review the generated changes
git diff circom/circuits/ noir/src/templates/

# Add and commit the changes  
git add circom/circuits/ noir/src/templates/
git commit -m "chore: regenerate templates after compiler changes"

# Push again
git push
```

**Manual hook installation** (if needed):
```bash
bun run install-hooks
```

**Emergency bypass** (use sparingly):
```bash
git push --no-verify origin my-branch
```

Open an issue to discuss major changes before submitting a pull request.

## Troubleshooting

### Version Compatibility Issues

**Circom version errors:**
```bash
# Check your circom version  
circom --help  # Should show >= 2.1.9

# Install Rust first (if needed)
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
source ~/.cargo/env

# Install/update circom from source (official method)
git clone https://github.com/iden3/circom.git
cd circom
cargo build --release
cargo install --path circom
```


**Bun installation issues:**
```bash
# Install/reinstall Bun
curl -fsSL https://bun.sh/install | bash

# Verify installation
bun --version  # Should show >= 1.0.0
```

**Test failures:**
```bash
# Run all tests
bun test

# Run specific test suites
bun run test:scripts  # TypeScript tests only
bun run test:circom   # Circom circuit tests only
```

```bash

@misc{zk-regex,
  author = {Gupta, Aayush and Londhe, Shreyas and Bisht, Aditya and Panda, Sampriti and Suegami, Sora},
  title = {ZK Regex},
  year         = {2025},
  publisher    = {Zenodo},
  howpublished = {\url{https://doi.org/10.5281/zenodo.15603470}},
  note         = {Software; archived via GitHub repository (original 2022)},
}
```


## License

This project is licensed under the [Specify License Here - e.g., MIT License or Apache 2.0].
