use thiserror::Error;

/// Error types for NFA operations
#[derive(Error, Debug)]
pub enum NFABuildError {
    #[error("Failed to build NFA: {0}")]
    Build(String),
    #[error("Invalid state ID: {0}")]
    InvalidStateId(String),
    #[error("Invalid transition: {0}")]
    InvalidTransition(String),
    #[error("Invalid capture group: {0}")]
    InvalidCapture(String),
    #[error("NFA verification failed: {0}")]
    Verification(String),
}

/// Result type for NFA operations
pub type NFAResult<T> = Result<T, NFABuildError>;
