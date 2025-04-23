use thiserror::Error;

/// Error type for the compiler.
#[derive(Error, Debug)]
pub enum CompilerError {
    #[error("Failed to compile regex pattern: {0}")]
    RegexCompilation(String),
    #[error("Failed to generate circuit inputs: {0}")]
    CircuitInputsGeneration(String),
}
