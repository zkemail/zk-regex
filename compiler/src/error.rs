//! Comprehensive error handling for the ZK-Regex compiler
//!
//! This module provides structured error types with error codes, context preservation,
//! and actionable error messages for users.

use std::fmt;
use thiserror::Error;

/// Error codes for programmatic error handling
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ErrorCode {
    // Regex validation errors (1000-1999)
    E1001, // InvalidRegexSyntax
    E1002, // UnsupportedRegexFeature
    E1003, // EmptyRegexPattern
    E1004, // RegexTooComplex

    // NFA construction errors (2000-2999)
    E2001, // NFAConstructionFailed
    E2002, // InvalidStateTransition
    E2003, // EpsilonRemovalFailed
    E2004, // StateValidationFailed

    // Circuit generation errors (3000-3999)
    E3001, // CircuitGenerationFailed
    E3002, // InvalidCaptureGroup
    E3003, // MaxBytesExceeded
    E3004, // TemplateGenerationFailed

    // Input validation errors (4000-4999)
    E4001, // InvalidInputLength
    E4002, // InputGenerationFailed
    E4003, // NoMatchFound
    E4004, // PathTraversalFailed,

    // Configuration errors (5000-5999)
    E5001, // InvalidConfiguration
    E5002, // UnsupportedFramework
    E5003, // MissingParameters

    // Internal errors (9000-9999)
    E9001, // SerializationError
    E9002, // DeserializationError
    E9003, // InternalError
}

impl fmt::Display for ErrorCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ErrorCode::E1001 => write!(f, "E1001"),
            ErrorCode::E1002 => write!(f, "E1002"),
            ErrorCode::E1003 => write!(f, "E1003"),
            ErrorCode::E1004 => write!(f, "E1004"),
            ErrorCode::E2001 => write!(f, "E2001"),
            ErrorCode::E2002 => write!(f, "E2002"),
            ErrorCode::E2003 => write!(f, "E2003"),
            ErrorCode::E2004 => write!(f, "E2004"),
            ErrorCode::E3001 => write!(f, "E3001"),
            ErrorCode::E3002 => write!(f, "E3002"),
            ErrorCode::E3003 => write!(f, "E3003"),
            ErrorCode::E3004 => write!(f, "E3004"),
            ErrorCode::E4001 => write!(f, "E4001"),
            ErrorCode::E4002 => write!(f, "E4002"),
            ErrorCode::E4003 => write!(f, "E4003"),
            ErrorCode::E4004 => write!(f, "E4004"),
            ErrorCode::E5001 => write!(f, "E5001"),
            ErrorCode::E5002 => write!(f, "E5002"),
            ErrorCode::E5003 => write!(f, "E5003"),
            ErrorCode::E9001 => write!(f, "E9001"),
            ErrorCode::E9002 => write!(f, "E9002"),
            ErrorCode::E9003 => write!(f, "E9003"),
        }
    }
}

/// Comprehensive error type for the ZK-Regex compiler
#[derive(Error, Debug)]
pub enum CompilerError {
    /// Regex pattern validation errors
    #[error("{code}: {message}")]
    RegexValidation {
        code: ErrorCode,
        message: String,
        pattern: Option<String>,
        position: Option<usize>,
        suggestion: Option<String>,
    },

    /// NFA construction and processing errors
    #[error("{code}: {message}")]
    NFAConstruction {
        code: ErrorCode,
        message: String,
        state_info: Option<String>,
        suggestion: Option<String>,
    },

    /// Circuit generation errors
    #[error("{code}: {message}")]
    CircuitGeneration {
        code: ErrorCode,
        message: String,
        template_name: Option<String>,
        framework: Option<String>,
        suggestion: Option<String>,
    },

    /// Input processing and validation errors
    #[error("{code}: {message}")]
    InputProcessing {
        code: ErrorCode,
        message: String,
        input_info: Option<String>,
        limits: Option<String>,
        suggestion: Option<String>,
    },

    /// Configuration errors
    #[error("{code}: {message}")]
    Configuration {
        code: ErrorCode,
        message: String,
        parameter: Option<String>,
        expected: Option<String>,
        suggestion: Option<String>,
    },

    /// Internal system errors
    #[error("{code}: Internal error - {message}")]
    Internal {
        code: ErrorCode,
        message: String,
        context: Option<String>,
    },
}

impl CompilerError {
    /// Get the error code for this error
    pub fn code(&self) -> ErrorCode {
        match self {
            CompilerError::RegexValidation { code, .. } => *code,
            CompilerError::NFAConstruction { code, .. } => *code,
            CompilerError::CircuitGeneration { code, .. } => *code,
            CompilerError::InputProcessing { code, .. } => *code,
            CompilerError::Configuration { code, .. } => *code,
            CompilerError::Internal { code, .. } => *code,
        }
    }

    /// Get a user-friendly error message with suggestions
    pub fn user_message(&self) -> String {
        let base_message = match self {
            CompilerError::RegexValidation {
                message,
                pattern,
                suggestion,
                ..
            } => {
                let mut msg = message.clone();
                if let Some(pattern) = pattern {
                    msg.push_str(&format!("\nPattern: '{}'", pattern));
                }
                if let Some(suggestion) = suggestion {
                    msg.push_str(&format!("\nSuggestion: {}", suggestion));
                }
                msg
            }
            CompilerError::NFAConstruction {
                message,
                suggestion,
                ..
            } => {
                let mut msg = message.clone();
                if let Some(suggestion) = suggestion {
                    msg.push_str(&format!("\nSuggestion: {}", suggestion));
                }
                msg
            }
            CompilerError::CircuitGeneration {
                message,
                suggestion,
                ..
            } => {
                let mut msg = message.clone();
                if let Some(suggestion) = suggestion {
                    msg.push_str(&format!("\nSuggestion: {}", suggestion));
                }
                msg
            }
            CompilerError::InputProcessing {
                message,
                suggestion,
                ..
            } => {
                let mut msg = message.clone();
                if let Some(suggestion) = suggestion {
                    msg.push_str(&format!("\nSuggestion: {}", suggestion));
                }
                msg
            }
            CompilerError::Configuration {
                message,
                suggestion,
                ..
            } => {
                let mut msg = message.clone();
                if let Some(suggestion) = suggestion {
                    msg.push_str(&format!("\nSuggestion: {}", suggestion));
                }
                msg
            }
            CompilerError::Internal {
                message, context, ..
            } => {
                let mut msg = format!("Internal error: {}", message);
                if let Some(context) = context {
                    msg.push_str(&format!("\nContext: {}", context));
                }
                msg.push_str("\nPlease report this issue with your regex pattern.");
                msg
            }
        };
        base_message
    }

    /// Check if this error is recoverable
    pub fn is_recoverable(&self) -> bool {
        matches!(
            self,
            CompilerError::RegexValidation { .. }
                | CompilerError::InputProcessing { .. }
                | CompilerError::Configuration { .. }
        )
    }
}

// Convenience constructors
impl CompilerError {
    pub fn invalid_regex_syntax(pattern: &str, message: &str, position: Option<usize>) -> Self {
        CompilerError::RegexValidation {
            code: ErrorCode::E1001,
            message: message.to_string(),
            pattern: Some(pattern.to_string()),
            position,
            suggestion: Some("Check regex syntax documentation".to_string()),
        }
    }

    pub fn unsupported_feature(pattern: &str, feature: &str) -> Self {
        CompilerError::RegexValidation {
            code: ErrorCode::E1002,
            message: format!("Unsupported regex feature: {}", feature),
            pattern: Some(pattern.to_string()),
            position: None,
            suggestion: Some(format!("Remove {} from your regex pattern", feature)),
        }
    }

    pub fn nfa_construction_failed(message: &str) -> Self {
        CompilerError::NFAConstruction {
            code: ErrorCode::E2001,
            message: message.to_string(),
            state_info: None,
            suggestion: Some("Try simplifying your regex pattern".to_string()),
        }
    }

    pub fn circuit_generation_failed(framework: &str, message: &str) -> Self {
        CompilerError::CircuitGeneration {
            code: ErrorCode::E3001,
            message: message.to_string(),
            template_name: None,
            framework: Some(framework.to_string()),
            suggestion: Some("Check template name and max_bytes configuration".to_string()),
        }
    }

    pub fn invalid_capture_config(group_count: usize, provided: usize) -> Self {
        CompilerError::CircuitGeneration {
            code: ErrorCode::E3002,
            message: format!(
                "Invalid capture group configuration: need {} max_bytes but got {}",
                group_count, provided
            ),
            template_name: None,
            framework: None,
            suggestion: Some(format!(
                "Provide exactly {} max_bytes values for capture groups",
                group_count
            )),
        }
    }

    pub fn input_too_long(actual: usize, max: usize) -> Self {
        CompilerError::InputProcessing {
            code: ErrorCode::E4001,
            message: format!("Input length {} exceeds maximum {}", actual, max),
            input_info: Some(format!("actual: {}, max: {}", actual, max)),
            limits: Some(format!("max_haystack_len: {}", max)),
            suggestion: Some("Increase max_haystack_len or reduce input size".to_string()),
        }
    }

    pub fn no_match_found(input: &str) -> Self {
        CompilerError::InputProcessing {
            code: ErrorCode::E4003,
            message: "No regex match found in input".to_string(),
            input_info: Some(format!("input length: {}", input.len())),
            limits: None,
            suggestion: Some("Check that your input contains the expected pattern".to_string()),
        }
    }

    pub fn serialization_error(context: &str, source: &str) -> Self {
        CompilerError::Internal {
            code: ErrorCode::E9001,
            message: format!("Serialization failed: {}", source),
            context: Some(context.to_string()),
        }
    }
}

/// Result type for compiler operations
pub type CompilerResult<T> = Result<T, CompilerError>;
