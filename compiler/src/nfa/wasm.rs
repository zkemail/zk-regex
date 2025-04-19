use crate::{
    DecomposedRegexConfig,
    compile, 
    nfa::{NFAGraph, codegen::{CircuitInputs, circom::CircomInputs, noir::NoirInputs}},
    utils::decomposed_to_composed_regex
};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use wasm_bindgen::prelude::*;


/// Supported proving systems
#[wasm_bindgen]
#[derive(Serialize, Deserialize, Debug, Clone, Copy)]
#[serde(rename_all = "camelCase")]
pub enum ProvingSystem {
    Circom,
    Noir,
    // Future systems:
    // Halo2,
}

/// Input types for different proving systems
#[derive(Serialize)]
#[serde(tag = "type")]
pub enum ProvingSystemInputs {
    #[serde(rename = "circom")]
    Circom(CircomInputs),
    #[serde(rename = "noir")]
    Noir(NoirInputs),
}

/// Output from regex compilation
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegexOutput {
    pub graph: String,
    pub code: String,
}

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
    provingSystem: ProvingSystem,
) -> Result<JsValue, JsValue> {
    let result =
        generate_from_decomposed_internal(decomposedRegexJson, templateName.into(), provingSystem);

    match result {
        Ok(output) => serde_wasm_bindgen::to_value(&output)
            .map_err(|e| WasmError::SerializationError(e.to_string()).into()),
        Err(e) => Err(e.into()),
    }
}

fn generate_from_decomposed_internal(
    decomposed_json: &str,
    template_name: TemplateName,
    proving_system: ProvingSystem,
) -> Result<RegexOutput, WasmError> {
    let decomposed_regex: DecomposedRegexConfig = serde_json::from_str(decomposed_json)?;
    let (composed_regex, max_substring_bytes) = decomposed_to_composed_regex(&decomposed_regex);

    generate_from_raw_internal(
        RawRegex(composed_regex),
        &max_substring_bytes,
        template_name,
        proving_system,
    )
}

/// Generate circuit from raw regex string
#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genFromRaw(
    rawRegex: &str,
    maxSubstringBytes: &[usize],
    templateName: &str,
    provingSystem: ProvingSystem,
) -> Result<JsValue, JsValue> {
    let result = generate_from_raw_internal(
        rawRegex.into(),
        maxSubstringBytes,
        templateName.into(),
        provingSystem,
    );

    match result {
        Ok(output) => serde_wasm_bindgen::to_value(&output)
            .map_err(|e| WasmError::SerializationError(e.to_string()).into()),
        Err(e) => Err(e.into()),
    }
}

fn generate_from_raw_internal(
    raw_regex: RawRegex,
    max_substring_bytes: &[usize],
    template_name: TemplateName,
    proving_system: ProvingSystem,
) -> Result<RegexOutput, WasmError> {
    let nfa = compile(&raw_regex.0).map_err(|e| WasmError::CompileError(e.to_string()))?;

    let graph = nfa
        .to_json()
        .map_err(|e| WasmError::SerializationError(e.to_string()))?;

    let code = match proving_system {
        ProvingSystem::Circom => nfa
            .generate_circom_code(&template_name.0, &raw_regex.0, Some(max_substring_bytes))
            .map_err(|e| WasmError::CodeGenError("circom".to_string(), e.to_string()))?,
        ProvingSystem::Noir => nfa
            .generate_noir_code(&raw_regex.0, Some(max_substring_bytes))
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
    provingSystem: ProvingSystem,
) -> Result<String, JsValue> {
    let result = generate_circuit_inputs_internal(
        regexGraphJson,
        haystack.into(),
        maxHaystackLength,
        maxMatchLength,
        provingSystem,
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
    proving_system: ProvingSystem,
) -> Result<String, WasmError> {
    let graph: NFAGraph =
        serde_json::from_str(graph_json).map_err(|e| WasmError::GraphParseError(e.to_string()))?;

    let inputs = match proving_system {
        ProvingSystem::Circom => {
            let inputs = graph
                .generate_circuit_inputs(&haystack.0, max_haystack_length, max_match_length)
                .map_err(|e| WasmError::InputGenError(e.to_string()))?;
            ProvingSystemInputs::Circom(CircomInputs::from(inputs))
        }
        ProvingSystem::Noir => {
            let inputs = NoirInputs::from(graph
                .generate_circuit_inputs(&haystack.0, max_haystack_length, max_match_length)
                .map_err(|e| WasmError::InputGenError(e.to_string()))?);
            ProvingSystemInputs::Noir(NoirInputs::from(inputs))
        }
    };

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
