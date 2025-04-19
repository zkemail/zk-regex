use std::num::ParseIntError;

use thiserror::Error;

/// Error types for NFA operations
#[derive(Error, Debug)]
pub enum NFAError {
    // Regex compilation errors
    #[error("Failed to compile regex pattern: {0}")]
    RegexCompilation(String),
    #[error("No match found in input: {0}")]
    NoMatch(String),
    // State errors
    #[error("Invalid state ID: {0}")]
    InvalidStateId(String),
    #[error("Invalid transition: {0}")]
    InvalidTransition(String),
    #[error("Empty automaton: {0}")]
    EmptyAutomaton(String),
    // Graph structure errors
    #[error("Graph verification failed: {0}")]
    Verification(String),
    // Path traversal errors
    #[error("No valid path found: {0}")]
    NoValidPath(String),
    // Input validation errors
    #[error("Invalid input: {0}")]
    InvalidInput(String),
    #[error("Input size exceeded: {0}")]
    InputSizeExceeded(String),
    // Capture group errors
    #[error("Invalid capture group configuration: {0}")]
    InvalidCapture(String),
    // Template generation errors
    #[error("Template generation error: {0}")]
    TemplateError(String),
    // Serialization errors
    #[error("Serialization error: {0}")]
    Serialization(String),
    #[error("Deserialization error: {0}")]
    Deserialization(String),
    // Integer parsing errors
    #[error("Integer parsing error: {0}")]
    ParseIntError(#[from] ParseIntError),
}

/// Result type for NFA operations
pub type NFAResult<T> = Result<T, NFAError>;
