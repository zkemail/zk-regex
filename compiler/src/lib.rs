//! ZK-Regex Compiler
//!
//! Converts regular expressions into circuit-friendly NFAs for zero-knowledge proofs.
//! Uses Thompson NFAs from regex-automata as an intermediate representation.

mod nfa;

pub use nfa::NFAGraph;
use nfa::NFAResult;

/// Compile a regular expression pattern into a circuit-friendly NFA
///
/// # Arguments
/// * `pattern` - The regular expression pattern to compile
///
/// # Returns
/// * `Result<NFAGraph, Error>` - The compiled NFA or an error
pub fn compile(pattern: &str) -> NFAResult<NFAGraph> {
    NFAGraph::build(pattern)
}
