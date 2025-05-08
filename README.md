# ZK-Regex: Verifiable Regular Expressions in Arithmetic Circuits

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

Installation details depend on which part of the project you need:

-   **Compiler:** If using the compiler directly in a Rust project, add it to your `Cargo.toml`. See [compiler/README.md](./compiler/README.md).
-   **Circom Helpers:** See [circom/README.md](./circom/README.md) for instructions on integrating the Circom templates.
-   **Noir Helpers:** See [noir/README.md](./noir/README.md) for instructions on adding the Noir library dependency.

## Contributing

Contributions are welcome! Please follow standard Rust development practices. Open an issue to discuss major changes before submitting a pull request.

## License

This project is licensed under the [Specify License Here - e.g., MIT License or Apache 2.0].
