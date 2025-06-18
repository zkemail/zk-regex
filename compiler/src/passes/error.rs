//! Error types for compiler passes

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

// Convert NFAError to CompilerError with proper categorization and context
impl From<NFAError> for crate::error::CompilerError {
    fn from(nfa_error: NFAError) -> Self {
        use crate::error::{CompilerError, ErrorCode};

        match nfa_error {
            NFAError::RegexCompilation(msg) => CompilerError::nfa_construction_failed(&msg),

            NFAError::InvalidStateId(msg) => CompilerError::NFAConstruction {
                code: ErrorCode::E2004,
                message: format!("State validation failed: {}", msg),
                state_info: Some(msg),
                suggestion: Some(
                    "This indicates an internal compiler issue. Please report this bug."
                        .to_string(),
                ),
            },

            NFAError::InvalidTransition(msg) => CompilerError::NFAConstruction {
                code: ErrorCode::E2002,
                message: format!("Invalid state transition: {}", msg),
                state_info: Some(msg),
                suggestion: Some(
                    "Try simplifying your regex pattern or report this as a bug.".to_string(),
                ),
            },

            NFAError::EmptyAutomaton(msg) => CompilerError::NFAConstruction {
                code: ErrorCode::E2001,
                message: format!("Empty NFA construction: {}", msg),
                state_info: None,
                suggestion: Some(
                    "Check that your regex pattern is not empty or malformed.".to_string(),
                ),
            },

            NFAError::Verification(msg) => CompilerError::NFAConstruction {
                code: ErrorCode::E2004,
                message: format!("NFA verification failed: {}", msg),
                state_info: Some(msg),
                suggestion: Some(
                    "This indicates a structural issue with the generated NFA.".to_string(),
                ),
            },

            NFAError::NoMatch(msg) => CompilerError::InputProcessing {
                code: ErrorCode::E4003,
                message: format!("No regex match found: {}", msg),
                input_info: Some(msg),
                limits: None,
                suggestion: Some(
                    "Ensure your input string contains the expected pattern.".to_string(),
                ),
            },

            NFAError::NoValidPath(msg) => CompilerError::InputProcessing {
                code: ErrorCode::E4004,
                message: format!("Path traversal failed: {}", msg),
                input_info: Some(msg),
                limits: None,
                suggestion: Some(
                    "The input doesn't match the regex pattern correctly.".to_string(),
                ),
            },

            NFAError::InvalidInput(msg) => CompilerError::InputProcessing {
                code: ErrorCode::E4001,
                message: format!("Invalid input: {}", msg),
                input_info: Some(msg),
                limits: None,
                suggestion: Some("Check input format and length constraints.".to_string()),
            },

            NFAError::InputSizeExceeded(msg) => CompilerError::InputProcessing {
                code: ErrorCode::E4001,
                message: format!("Input size limit exceeded: {}", msg),
                input_info: Some(msg),
                limits: None,
                suggestion: Some(
                    "Reduce input size or increase max_haystack_len parameter.".to_string(),
                ),
            },

            NFAError::InvalidCapture(msg) => CompilerError::CircuitGeneration {
                code: ErrorCode::E3002,
                message: format!("Invalid capture group configuration: {}", msg),
                template_name: None,
                framework: None,
                suggestion: Some("Check max_bytes parameter for capture groups.".to_string()),
            },

            NFAError::TemplateError(msg) => CompilerError::CircuitGeneration {
                code: ErrorCode::E3004,
                message: format!("Template generation failed: {}", msg),
                template_name: None,
                framework: None,
                suggestion: Some("Check template name and framework configuration.".to_string()),
            },

            NFAError::Serialization(msg) => {
                CompilerError::serialization_error("NFA serialization", &msg)
            }

            NFAError::Deserialization(msg) => CompilerError::Internal {
                code: ErrorCode::E9002,
                message: format!("Deserialization failed: {}", msg),
                context: Some("NFA deserialization".to_string()),
            },

            NFAError::ParseIntError(err) => CompilerError::Internal {
                code: ErrorCode::E9003,
                message: format!("Integer parsing error: {}", err),
                context: Some("NFA integer parsing".to_string()),
            },
        }
    }
}
