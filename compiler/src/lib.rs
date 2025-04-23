//! ZK-Regex Compiler
//!
//! Converts regular expressions into circuit-friendly NFAs for zero-knowledge proofs.
//! Uses Thompson NFAs from regex-automata as an intermediate representation.

mod error;
mod nfa;
mod types;
mod utils;
mod wasm;

pub use error::*;
pub use nfa::*;
pub use types::*;
pub use utils::*;
pub use wasm::*;

use nfa::{circom::generate_circom_code, noir::generate_noir_code};

/// Compile a regular expression pattern into a circuit-friendly NFA
///
/// # Arguments
/// * `pattern` - The regular expression pattern to compile
///
/// # Returns
/// * `Result<NFAGraph, Error>` - The compiled NFA or an error
pub fn compile(pattern: &str) -> Result<NFAGraph, CompilerError> {
    NFAGraph::build(pattern).map_err(|e| CompilerError::RegexCompilation(e.to_string()))
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
/// * `Result<(NFAGraph, String), CompilerError>` - The compiled NFA and circuit code
pub fn gen_from_raw(
    pattern: &str,
    max_bytes: Option<Vec<usize>>,
    template_name: &str,
    proving_framework: ProvingFramework,
) -> Result<(NFAGraph, String), CompilerError> {
    let nfa = compile(&pattern)?;
    let code = match proving_framework {
        ProvingFramework::Circom => generate_circom_code(&nfa, &template_name, &pattern, max_bytes)
            .map_err(|e| CompilerError::RegexCompilation(e.to_string()))?,
        ProvingFramework::Noir => generate_noir_code(&nfa, &pattern, max_bytes)
            .map_err(|e| CompilerError::RegexCompilation(e.to_string()))?,
    };

    Ok((nfa, code))
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
/// * `Result<(NFAGraph, String), CompilerError>` - The compiled NFA and circuit code
pub fn gen_from_decomposed(
    config: DecomposedRegexConfig,
    template_name: &str,
    proving_framework: ProvingFramework,
) -> Result<(NFAGraph, String), CompilerError> {
    let (combined_pattern, max_bytes) = decomposed_to_composed_regex(&config);
    let (nfa, code) = gen_from_raw(
        &combined_pattern,
        max_bytes,
        template_name,
        proving_framework,
    )?;

    Ok((nfa, code))
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
/// * `Result<ProverInputs, CompilerError>` - Framework-specific circuit inputs
pub fn gen_circuit_inputs(
    nfa: &NFAGraph,
    input: &str,
    max_haystack_len: usize,
    max_match_len: usize,
    proving_framework: ProvingFramework,
) -> Result<ProverInputs, CompilerError> {
    let inputs = generate_circuit_inputs(
        &nfa,
        &input,
        max_haystack_len,
        max_match_len,
        proving_framework,
    )
    .map_err(|e| CompilerError::CircuitInputsGeneration(e.to_string()))?;

    Ok(inputs)
}
