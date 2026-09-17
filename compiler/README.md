# ZK-Regex Compiler

This package contains the core Rust library for compiling regular expressions into circuit-friendly Non-deterministic Finite Automata (NFAs) and generating circuit code for Circom and Noir.

It uses the [`regex-automata`](https://github.com/rust-lang/regex/tree/master/regex-automata) crate to parse regex patterns and construct Thompson NFAs, which are then processed to create structures suitable for arithmetic circuits.

## Core API

The main functionalities are exposed through the [`lib.rs`](./src/lib.rs) file:

-   **`compile(pattern: &str) -> Result<NFAGraph, CompilerError>`**

    -   Parses the input regex `pattern` string.
    -   Builds an internal NFA representation ([`NFAGraph`](./src/types.rs)).
    -   Returns the `NFAGraph` or a [`CompilerError::RegexCompilation`](./src/error.rs) if the pattern is invalid.

-   **`gen_from_raw(pattern: &str, max_bytes: Option<Vec<usize>>, template_name: &str, proving_framework: ProvingFramework) -> Result<(NFAGraph, String), CompilerError>`**

    -   Compiles a raw regex `pattern` string directly into circuit code.
    -   `max_bytes`: Optional vector specifying maximum byte lengths for each capture group. If `None`, defaults might be used or capture groups might not be specifically handled (verify this behavior).
    -   `template_name`: A name used for the main template/contract in the generated code (e.g., Circom template name).
    -   `proving_framework`: Specifies the target output ([`ProvingFramework::Circom`](./src/types.rs#L23) or [`ProvingFramework::Noir`](./src/types.rs#L23)).
    -   Returns a tuple containing the compiled [`NFAGraph`](./src/nfa/mod.rs#L32) and the generated circuit code as a `String`, or a [`CompilerError`](./src/error.rs#L5).

-   **`gen_from_decomposed(config: DecomposedRegexConfig, template_name: &str, proving_framework: ProvingFramework) -> Result<(NFAGraph, String), CompilerError>`**

    -   Constructs a regex pattern by combining parts defined in the `config` (of type [`DecomposedRegexConfig`](./src/types.rs#L15)).
    -   Generates circuit code similarly to `gen_from_raw`.
    -   Useful for building complex regex patterns programmatically.
    -   Returns a tuple containing the compiled [`NFAGraph`](./src/nfa/mod.rs#L32) and the generated circuit code as a `String`, or a [`CompilerError`](./src/error.rs#L5).
    -   _(Note: Requires understanding the structure of [`DecomposedRegexConfig`](./src/types.rs#L15))_

-   **`gen_circuit_inputs(nfa: &NFAGraph, input: &str, max_haystack_len: usize, max_match_len: usize, proving_framework: ProvingFramework) -> Result<ProverInputs, CompilerError>`**

    -   Generates the necessary inputs for the prover based on the compiled [`nfa`](./src/nfa/mod.rs#L32), the `input` string to match against, and circuit constraints.
    -   `max_haystack_len`: The maximum length of the input string allowed by the circuit.
    -   `max_match_len`: The maximum length of the regex match allowed by the circuit.
    -   `proving_framework`: Specifies for which framework ([`Circom`](./src/types.rs#L23) or [`Noir`](./src/types.rs#L23)) the inputs should be formatted.
    -   Returns a [`ProverInputs`](./src/types.rs#L33) struct (containing formatted public and private inputs) or a [`CompilerError::CircuitInputsGeneration`](./src/error.rs).
    -   _(Note: Requires understanding the structure of [`ProverInputs`](./src/types.rs#L33) for the specific framework)_

## Usage Examples (Rust)

Add this crate to your `Cargo.toml`:

```toml
[dependencies]
zk-regex-compiler = { git = "https://github.com/zkemail/zk-regex", package = "compiler" }
```

**Example 1: Compile a simple regex to NFA**

```rust
use zk_regex_compiler::{compile, CompilerError};

fn main() -> Result<(), CompilerError> {
    let pattern = r"^a+b*$";
    let nfa = compile(pattern)?;
    println!("Successfully compiled regex to NFA with {} states.", nfa.states().len());
    // You can now inspect the nfa graph structure
    Ok(())
}
```

**Example 2: Generate Circom Code**

```rust
use zk_regex_compiler::{gen_from_raw, ProvingFramework, CompilerError};

fn main() -> Result<(), CompilerError> {
    let pattern = r"(a|b){2,3}";
    let template_name = "ABRegex";
    let (nfa, circom_code) = gen_from_raw(pattern, None, template_name, ProvingFramework::Circom)?;

    println!("Generated Circom Code:\n{}", circom_code);
    // Save circom_code to a .circom file or use it directly
    Ok(())
}
```

**Example 3: Generate Noir Code**

```rust
use zk_regex_compiler::{gen_from_raw, ProvingFramework, CompilerError};

fn main() -> Result<(), CompilerError> {
    let pattern = r"\d{3}-\d{3}-\d{4}"; // Example: Phone number
    let template_name = "PhoneRegex";
    let (nfa, noir_code) = gen_from_raw(pattern, None, template_name, ProvingFramework::Noir)?;

    println!("Generated Noir Code:\n{}", noir_code);
    // Save noir_code to a .nr file or integrate into a Noir project
    Ok(())
}
```

**Example 4: Generate Circuit Inputs**

```rust
use zk_regex_compiler::{compile, gen_circuit_inputs, ProvingFramework, CompilerError};

fn main() -> Result<(), CompilerError> {
    let pattern = r"abc";
    let nfa = compile(pattern)?;

    let input_str = "test abc test";
    let max_haystack_len = 64; // Must match circuit parameter
    let max_match_len = 16;   // Must match circuit parameter

    // Generate inputs for Circom
    let circom_inputs = gen_circuit_inputs(&nfa, input_str, max_haystack_len, max_match_len, ProvingFramework::Circom)?;
    println!("Circom Inputs: {:?}", circom_inputs); // Need to format/serialize ProverInputs

    // Generate inputs for Noir
    let noir_inputs = gen_circuit_inputs(&nfa, input_str, max_haystack_len, max_match_len, ProvingFramework::Noir)?;
    println!("Noir Inputs: {:?}", noir_inputs); // Need to format/serialize ProverInputs

    Ok(())
}
```

## Error Handling

The library uses the [`CompilerError`](./src/error.rs) enum to report issues:

-   `RegexCompilation(String)`: An error occurred during regex parsing or NFA construction (from [`regex-automata`](https://github.com/rust-lang/regex/tree/master/regex-automata)).
-   `CircuitGeneration(String)`: An error occurred during the generation of Circom or Noir code.
-   `CircuitInputsGeneration(String)`: An error occurred while generating prover inputs for a given string.

Match on the enum variants to handle errors appropriately.

## Building & Testing

Navigate to the `compiler/` directory and use standard Cargo commands:

```bash
cargo build --release
cargo test
```
