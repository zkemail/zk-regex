use crate::{
    DecomposedRegexConfig, ProvingFramework, RegexOutput, circom::generate_circom_code, compile,
    generate_circuit_inputs, nfa::NFAGraph, noir::generate_noir_code,
    utils::decomposed_to_composed_regex,
};
use thiserror::Error;
use wasm_bindgen::prelude::*;

/// WASM-specific error type
#[derive(Error, Debug)]
pub enum WasmError {
    #[error("Failed to parse decomposed regex: {0}")]
    DecomposedParseError(#[from] serde_json::Error),
    #[error("Failed to compile regex: {0}")]
    CompileError(String),
    #[error("Failed to generate {0} code: {1}")]
    CodeGenError(String, String),
    #[error("Failed to serialize output: {0}")]
    SerializationError(String),
    #[error("Failed to parse regex graph: {0}")]
    GraphParseError(String),
    #[error("Failed to generate inputs: {0}")]
    InputGenError(String),
    #[error("Proving system not implemented: {0}")]
    UnimplementedSystem(String),
}

impl From<WasmError> for JsValue {
    fn from(err: WasmError) -> Self {
        JsValue::from_str(&err.to_string())
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
        Ok(output) => serde_wasm_bindgen::to_value(&output)
            .map_err(|e| WasmError::SerializationError(e.to_string()).into()),
        Err(e) => Err(e.into()),
    }
}

fn generate_from_decomposed_internal(
    decomposed_json: &str,
    template_name: TemplateName,
    proving_framework: ProvingFramework,
) -> Result<RegexOutput, WasmError> {
    let decomposed_regex: DecomposedRegexConfig = serde_json::from_str(decomposed_json)?;
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
        Ok(output) => serde_wasm_bindgen::to_value(&output)
            .map_err(|e| WasmError::SerializationError(e.to_string()).into()),
        Err(e) => Err(e.into()),
    }
}

fn generate_from_raw_internal(
    raw_regex: RawRegex,
    max_substring_bytes: Option<Vec<usize>>,
    template_name: TemplateName,
    proving_framework: ProvingFramework,
) -> Result<RegexOutput, WasmError> {
    let nfa = compile(&raw_regex.0).map_err(|e| WasmError::CompileError(e.to_string()))?;

    let graph = nfa
        .to_json()
        .map_err(|e| WasmError::SerializationError(e.to_string()))?;

    let code = match proving_framework {
        ProvingFramework::Circom => {
            generate_circom_code(&nfa, &template_name.0, &raw_regex.0, max_substring_bytes)
                .map_err(|e| WasmError::CodeGenError("circom".to_string(), e.to_string()))?
        }
        ProvingFramework::Noir => generate_noir_code(&nfa, &raw_regex.0, max_substring_bytes)
            .map_err(|e| WasmError::CodeGenError("noir".to_string(), e.to_string()))?,
    };

    Ok(RegexOutput { graph, code })
}

/// Generate circuit inputs for a regex match
#[wasm_bindgen]
#[allow(non_snake_case)]
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
    let nfa: NFAGraph =
        serde_json::from_str(graph_json).map_err(|e| WasmError::GraphParseError(e.to_string()))?;

    let inputs = generate_circuit_inputs(
        &nfa,
        &haystack.0,
        max_haystack_length,
        max_match_length,
        proving_framework,
    )
    .map_err(|e| WasmError::InputGenError(e.to_string()))?;

    serde_json::to_string(&inputs).map_err(|e| WasmError::SerializationError(e.to_string()))
}

/// Pad a string to the specified length with null bytes
#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn padString(input: &str, maxLength: usize) -> Vec<u8> {
    let mut bytes = input.as_bytes().to_vec();

    if bytes.len() > maxLength {
        bytes.truncate(maxLength);
    } else {
        bytes.resize(maxLength, 0);
    }

    bytes
}
