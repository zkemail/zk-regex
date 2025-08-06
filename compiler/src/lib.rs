//! ZK-Regex Compiler
//!
//! Converts regular expressions into circuit-friendly NFAs for zero-knowledge proofs.
//! Uses Thompson NFAs from regex-automata as an intermediate representation.

mod backend;
mod driver;
mod error;
mod ir;
mod passes;
mod types;
mod utils;
mod wasm;

pub use backend::*;
pub use driver::*;
pub use error::*;
pub use ir::*;
pub use passes::*;
pub use types::*;
pub use utils::*;
pub use wasm::*;

/// Compile a regular expression pattern into a circuit-friendly NFA
///
/// # Arguments
/// * `pattern` - The regular expression pattern to compile
///
/// # Returns
/// * `CompilerResult<NFAGraph>` - The compiled NFA or a structured error with error code
///
/// # Example
/// ```rust
/// use zk_regex_compiler::compile;
///
/// let nfa = compile(r"hello \w+").expect("Valid regex");
/// println!("Compiled NFA with {} states", nfa.state_count());
/// ```
pub fn compile(pattern: &str) -> CompilerResult<NFAGraph> {
    NFAGraph::build(pattern).map_err(CompilerError::from)
}

/// Generate a circuit from a raw regex pattern
///
/// Takes a regex pattern and generates code for the specified proving framework.
///
/// # Arguments
/// * `pattern` - The regex pattern to compile
/// * `max_bytes` - Optional maximum byte lengths for capture groups
/// * `template_name` - Name of the generated template (used in Circom)
/// * `proving_framework` - Target proving framework (Circom or Noir)
///
/// # Returns
/// * `CompilerResult<(NFAGraph, String)>` - The compiled NFA and circuit code
///
/// # Errors
/// * `E1001` - Invalid regex syntax
/// * `E1002` - Unsupported regex features
/// * `E3002` - Invalid capture group configuration
/// * `E5001` - Invalid configuration parameters
///
/// # Example
/// ```rust
/// use zk_regex_compiler::{gen_from_raw, ProvingFramework};
///
/// let (nfa, code) = gen_from_raw(
///     r"(\w+)@(\w+\.\w+)",
///     Some(vec![20, 30]),
///     "EmailRegex",
///     ProvingFramework::Circom
/// ).expect("Valid email regex");
/// ```
pub fn gen_from_raw(
    pattern: &str,
    max_bytes: Option<Vec<usize>>,
    template_name: &str,
    proving_framework: ProvingFramework,
) -> CompilerResult<(NFAGraph, String)> {
    let config = CompilationConfig {
        template_name: template_name.to_string(),
        proving_framework,
        max_bytes,
        optimize: true,
    };

    let result = Driver::compile(pattern, config)?;
    Ok((result.nfa, result.code))
}

/// Generate a circuit from a decomposed regex configuration
///
/// Combines regex parts from a configuration and generates circuit code.
///
/// # Arguments
/// * `config` - Decomposed regex configuration with pattern parts
/// * `template_name` - Name of the generated template (used in Circom)
/// * `proving_framework` - Target proving framework (Circom or Noir)
///
/// # Returns
/// * `CompilerResult<(NFAGraph, String)>` - The compiled NFA and circuit code
///
/// # Example
/// ```rust
/// use zk_regex_compiler::{gen_from_decomposed, DecomposedRegexConfig, RegexPart, ProvingFramework};
///
/// let config = DecomposedRegexConfig {
///     parts: vec![
///         RegexPart::Pattern("prefix:".to_string()),
///         RegexPart::PublicPattern(("\\w+".to_string(), 20)),
///     ]
/// };
/// let (nfa, code) = gen_from_decomposed(config, "PrefixRegex", ProvingFramework::Noir).unwrap();
/// ```
pub fn gen_from_decomposed(
    config: DecomposedRegexConfig,
    template_name: &str,
    proving_framework: ProvingFramework,
) -> CompilerResult<(NFAGraph, String)> {
    let (combined_pattern, max_bytes) = decomposed_to_composed_regex(&config);
    gen_from_raw(
        &combined_pattern,
        max_bytes,
        template_name,
        proving_framework,
    )
}

/// Generate circuit inputs for a regex match
///
/// Creates prover inputs for verification of a regex match.
///
/// # Arguments
/// * `nfa` - The compiled NFA graph
/// * `input` - String to match against the regex
/// * `max_haystack_len` - Maximum input string length in the circuit
/// * `max_match_len` - Maximum match length in the circuit
/// * `proving_framework` - Target proving framework (Circom or Noir)
///
/// # Returns
/// * `CompilerResult<ProverInputs>` - Framework-specific circuit inputs
///
/// # Errors
/// * `E4001` - Input length exceeds maximum
/// * `E4003` - No regex match found in input
/// * `E4004` - Path traversal failed
///
/// # Example
/// ```rust
/// use zk_regex_compiler::{compile, gen_circuit_inputs, ProvingFramework};
///
/// let nfa = compile(r"hello (\w+)").expect("Valid regex");
/// let inputs = gen_circuit_inputs(
///     &nfa,
///     "hello world",
///     1024,
///     64,
///     ProvingFramework::Circom
/// ).expect("Valid input");
/// ```
pub fn gen_circuit_inputs(
    nfa: &NFAGraph,
    input: &str,
    max_haystack_len: usize,
    max_match_len: usize,
    proving_framework: ProvingFramework,
) -> CompilerResult<ProverInputs> {
    // Validate input length upfront with specific error
    if input.len() > max_haystack_len {
        return Err(CompilerError::input_too_long(input.len(), max_haystack_len));
    }

    crate::backend::generate_circuit_inputs(
        nfa,
        input,
        max_haystack_len,
        max_match_len,
        proving_framework,
    )
    .map_err(|nfa_err| {
        // Convert NFAError to more specific input processing errors
        match nfa_err {
            crate::passes::NFAError::NoMatch(_) => CompilerError::no_match_found(input),
            crate::passes::NFAError::InvalidInput(msg) => {
                if msg.contains("exceeds maximum") {
                    CompilerError::input_too_long(input.len(), max_haystack_len)
                } else {
                    CompilerError::InputProcessing {
                        code: ErrorCode::E4002,
                        message: format!("Input generation failed: {}", msg),
                        input_info: Some(format!("input_len: {}", input.len())),
                        limits: Some(format!(
                            "max_haystack: {}, max_match: {}",
                            max_haystack_len, max_match_len
                        )),
                        suggestion: Some("Check input format and circuit parameters".to_string()),
                    }
                }
            }
            other => CompilerError::from(other),
        }
    })
}
