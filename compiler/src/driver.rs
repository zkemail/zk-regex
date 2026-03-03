//! Compilation driver for the ZK-Regex compiler
//!
//! This module orchestrates the compilation pipeline, taking regex patterns
//! through various transformation passes to generate circuit code.

use crate::{
    error::{CompilerError, CompilerResult},
    ir::NFAGraph,
    types::ProvingFramework,
};

/// Configuration for the compilation process
#[derive(Debug, Clone)]
pub struct CompilationConfig {
    pub template_name: String,
    pub proving_framework: ProvingFramework,
    pub max_bytes: Option<Vec<usize>>,
    pub optimize: bool,
}

impl CompilationConfig {
    /// Validate the compilation configuration
    pub fn validate(&self) -> CompilerResult<()> {
        if self.template_name.is_empty() {
            return Err(CompilerError::Configuration {
                code: crate::error::ErrorCode::E5001,
                message: "Template name cannot be empty".to_string(),
                parameter: Some("template_name".to_string()),
                expected: Some("Non-empty string".to_string()),
                suggestion: Some("Provide a valid template name".to_string()),
            });
        }
        // Check for invalid characters or patterns in template name
        if self.template_name.chars().any(|c| c.is_whitespace()) {
            return Err(CompilerError::Configuration {
                code: crate::error::ErrorCode::E5001,
                message: "Template name cannot contain spaces or whitespace characters".to_string(),
                parameter: Some("template_name".to_string()),
                expected: Some("String without spaces".to_string()),
                suggestion: Some("Use underscores or camelCase instead of spaces".to_string()),
            });
        }
        Ok(())
    }
}

/// Result of the compilation process
#[derive(Debug)]
pub struct CompilationResult {
    pub nfa: NFAGraph,
    pub code: String,
}

/// Main compilation driver
pub struct Driver;

impl Driver {
    /// Compile a regex pattern into circuit code
    pub fn compile(pattern: &str, config: CompilationConfig) -> CompilerResult<CompilationResult> {
        // Validate configuration
        config.validate()?;

        // Validate regex pattern
        if pattern.is_empty() {
            return Err(CompilerError::RegexValidation {
                code: crate::error::ErrorCode::E1003,
                message: "Regex pattern cannot be empty".to_string(),
                pattern: Some(pattern.to_string()),
                position: None,
                suggestion: Some("Provide a non-empty regex pattern".to_string()),
            });
        }

        // Build NFA from pattern - this automatically converts NFAError to CompilerError
        let nfa = NFAGraph::build(pattern)?;

        // Backend: generate code with better error handling
        let code = match config.proving_framework {
            ProvingFramework::Circom => {
                let max_bytes_clone = config.max_bytes.clone();
                crate::backend::generate_circom_code(
                    &nfa,
                    &config.template_name,
                    pattern,
                    config.max_bytes,
                )
                .map_err(|nfa_err| {
                    // Convert NFAError to more specific CompilerError for circuit generation
                    match nfa_err {
                        crate::passes::NFAError::InvalidCapture(msg) => {
                            CompilerError::invalid_capture_config(
                                nfa.num_capture_groups,
                                max_bytes_clone.as_ref().map(|v| v.len()).unwrap_or(0),
                            )
                        }
                        crate::passes::NFAError::InvalidInput(msg) => {
                            CompilerError::circuit_generation_failed("Circom", &msg)
                        }
                        other => CompilerError::from(other),
                    }
                })?
            }
            ProvingFramework::Noir => {
                let max_bytes_clone = config.max_bytes.clone();
                crate::backend::generate_noir_code(
                    &nfa,
                    &config.template_name,
                    pattern,
                    config.max_bytes,
                )
                .map_err(|nfa_err| {
                    // Convert NFAError to more specific CompilerError for circuit generation
                    match nfa_err {
                        crate::passes::NFAError::InvalidCapture(msg) => {
                            CompilerError::invalid_capture_config(
                                nfa.num_capture_groups,
                                max_bytes_clone.as_ref().map(|v| v.len()).unwrap_or(0),
                            )
                        }
                        crate::passes::NFAError::InvalidInput(msg) => {
                            CompilerError::circuit_generation_failed("Noir", &msg)
                        }
                        other => CompilerError::from(other),
                    }
                })?
            }
        };

        Ok(CompilationResult { nfa, code })
    }
}
