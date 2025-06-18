//! Compilation driver for the ZK-Regex compiler
//!
//! This module orchestrates the compilation pipeline, taking regex patterns
//! through various transformation passes to generate circuit code.

use crate::{error::CompilerError, ir::NFAGraph, types::ProvingFramework};

/// Configuration for the compilation process
#[derive(Debug, Clone)]
pub struct CompilationConfig {
    pub template_name: String,
    pub proving_framework: ProvingFramework,
    pub max_bytes: Option<Vec<usize>>,
    pub optimize: bool,
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
    pub fn compile(
        pattern: &str,
        config: CompilationConfig,
    ) -> Result<CompilationResult, CompilerError> {
        // Build NFA from pattern
        let nfa =
            NFAGraph::build(pattern).map_err(|e| CompilerError::RegexCompilation(e.to_string()))?;

        // TODO: Add optimization passes here when implemented

        // Backend: generate code
        let code = match config.proving_framework {
            ProvingFramework::Circom => crate::backend::generate_circom_code(
                &nfa,
                &config.template_name,
                pattern,
                config.max_bytes,
            )
            .map_err(|e| CompilerError::RegexCompilation(e.to_string()))?,
            ProvingFramework::Noir => crate::backend::generate_noir_code(
                &nfa,
                &config.template_name,
                pattern,
                config.max_bytes,
            )
            .map_err(|e| CompilerError::RegexCompilation(e.to_string()))?,
        };

        Ok(CompilationResult { nfa, code })
    }
}
