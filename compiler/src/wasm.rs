use crate::{
    DecomposedRegexConfig, ProvingFramework, RegexOutput,
    backend::{generate_circom_code, generate_noir_code},
    compile,
    error::{CompilerError, CompilerResult, ErrorCode},
    gen_circuit_inputs,
    ir::NFAGraph,
    utils::decomposed_to_composed_regex,
};
use thiserror::Error;
use wasm_bindgen::prelude::*;

/// WASM-specific error type that converts from CompilerError
#[derive(Error, Debug)]
pub enum WasmError {
    #[error("Compiler error {code}: {message}")]
    CompilerError { code: String, message: String },
}

impl From<CompilerError> for WasmError {
    fn from(err: CompilerError) -> Self {
        WasmError::CompilerError {
            code: err.code().to_string(),
            message: err.user_message(),
        }
    }
}

impl From<WasmError> for JsValue {
    fn from(err: WasmError) -> Self {
        // Return a structured error message that JavaScript can parse
        match err {
            WasmError::CompilerError { code, message } => {
                let error_json = format!(
                    r#"{{"type": "CompilerError", "code": "{}", "message": "{}"}}"#,
                    code,
                    message.replace('"', "\\\"").replace('\n', "\\n")
                );
                JsValue::from_str(&error_json)
            }
        }
    }
}

/// Type-safe wrappers for primitive types
#[derive(Debug, Clone)]
pub struct TemplateName(String);
#[derive(Debug, Clone)]
pub struct RawRegex(String);
#[derive(Debug, Clone)]
pub struct Haystack(String);

impl From<&str> for TemplateName {
    fn from(s: &str) -> Self {
        Self(s.to_string())
    }
}

impl From<&str> for RawRegex {
    fn from(s: &str) -> Self {
        Self(s.to_string())
    }
}

impl From<&str> for Haystack {
    fn from(s: &str) -> Self {
        Self(s.to_string())
    }
}

/// Generate circuit from decomposed regex configuration
#[wasm_bindgen]
#[allow(non_snake_case)]
#[cfg(target_arch = "wasm32")]
pub fn genFromDecomposed(
    decomposedRegexJson: &str,
    templateName: &str,
    proving_framework: ProvingFramework,
) -> Result<JsValue, JsValue> {
    let result = generate_from_decomposed_internal(
        decomposedRegexJson,
        templateName.into(),
        proving_framework,
    );

    match result {
        Ok(output) => serde_wasm_bindgen::to_value(&output).map_err(|e| {
            let compiler_err = CompilerError::serialization_error("WASM output", &e.to_string());
            WasmError::from(compiler_err).into()
        }),
        Err(e) => Err(e.into()),
    }
}

fn generate_from_decomposed_internal(
    decomposed_json: &str,
    template_name: TemplateName,
    proving_framework: ProvingFramework,
) -> Result<RegexOutput, WasmError> {
    let decomposed_regex: DecomposedRegexConfig =
        serde_json::from_str(decomposed_json).map_err(|e| CompilerError::Internal {
            code: ErrorCode::E9002,
            message: format!("Failed to parse decomposed regex JSON: {}", e),
            context: Some("WASM deserialization".to_string()),
        })?;

    let (composed_regex, max_substring_bytes) = decomposed_to_composed_regex(&decomposed_regex);

    generate_from_raw_internal(
        RawRegex(composed_regex),
        max_substring_bytes,
        template_name,
        proving_framework,
    )
}

/// Generate circuit from raw regex string
#[wasm_bindgen]
#[allow(non_snake_case)]
#[cfg(target_arch = "wasm32")]
pub fn genFromRaw(
    rawRegex: &str,
    maxSubstringBytes: Option<Vec<usize>>,
    templateName: &str,
    provingFramework: ProvingFramework,
) -> Result<JsValue, JsValue> {
    let result = generate_from_raw_internal(
        rawRegex.into(),
        maxSubstringBytes,
        templateName.into(),
        provingFramework,
    );

    match result {
        Ok(output) => serde_wasm_bindgen::to_value(&output).map_err(|e| {
            let compiler_err = CompilerError::serialization_error("WASM output", &e.to_string());
            WasmError::from(compiler_err).into()
        }),
        Err(e) => Err(e.into()),
    }
}

fn generate_from_raw_internal(
    raw_regex: RawRegex,
    max_substring_bytes: Option<Vec<usize>>,
    template_name: TemplateName,
    proving_framework: ProvingFramework,
) -> Result<RegexOutput, WasmError> {
    let nfa = compile(&raw_regex.0)?;

    let graph = nfa
        .to_json()
        .map_err(|nfa_err| CompilerError::from(nfa_err))?;

    let code = match proving_framework {
        ProvingFramework::Circom => {
            generate_circom_code(
                &nfa,
                &template_name.0,
                &raw_regex.0,
                max_substring_bytes.clone(),
            )
            .map_err(|nfa_err| {
                // Provide specific error handling for common WASM use cases
                match nfa_err {
                    crate::passes::NFAError::InvalidCapture(_) => {
                        CompilerError::invalid_capture_config(
                            nfa.num_capture_groups,
                            max_substring_bytes.as_ref().map(|v| v.len()).unwrap_or(0),
                        )
                    }
                    other => CompilerError::from(other),
                }
            })?
        }
        ProvingFramework::Noir => generate_noir_code(
            &nfa,
            &template_name.0,
            &raw_regex.0,
            max_substring_bytes.clone(),
        )
        .map_err(|nfa_err| match nfa_err {
            crate::passes::NFAError::InvalidCapture(_) => CompilerError::invalid_capture_config(
                nfa.num_capture_groups,
                max_substring_bytes.as_ref().map(|v| v.len()).unwrap_or(0),
            ),
            other => CompilerError::from(other),
        })?,
    };

    Ok(RegexOutput { graph, code })
}

/// Generate circuit inputs for a regex match
#[wasm_bindgen]
#[allow(non_snake_case)]
#[cfg(target_arch = "wasm32")]
pub fn genCircuitInputs(
    regexGraphJson: &str,
    haystack: &str,
    maxHaystackLength: usize,
    maxMatchLength: usize,
    provingFramework: ProvingFramework,
) -> Result<String, JsValue> {
    let result = generate_circuit_inputs_internal(
        regexGraphJson,
        haystack.into(),
        maxHaystackLength,
        maxMatchLength,
        provingFramework,
    );

    match result {
        Ok(inputs_json) => Ok(inputs_json),
        Err(e) => Err(e.into()),
    }
}

fn generate_circuit_inputs_internal(
    graph_json: &str,
    haystack: Haystack,
    max_haystack_length: usize,
    max_match_length: usize,
    proving_framework: ProvingFramework,
) -> Result<String, WasmError> {
    let nfa: NFAGraph = serde_json::from_str(graph_json).map_err(|e| CompilerError::Internal {
        code: ErrorCode::E9002,
        message: format!("Failed to parse NFA graph JSON: {}", e),
        context: Some("WASM graph deserialization".to_string()),
    })?;

    let inputs = gen_circuit_inputs(
        &nfa,
        &haystack.0,
        max_haystack_length,
        max_match_length,
        proving_framework,
    )?;

    serde_json::to_string(&inputs)
        .map_err(|e| CompilerError::serialization_error("Circuit inputs", &e.to_string()).into())
}
