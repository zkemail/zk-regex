use crate::{DecomposedRegexConfig, compile, nfa::NFAGraph, utils::decomposed_to_composed_regex};
use serde::{Deserialize, Serialize};
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProvingSystem {
    Circom,
    // Future systems:
    // Halo2,
    // Noir,
    // etc.
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genFromDecomposed(
    decomposedRegexJson: &str,
    templateName: &str,
    provingSystem: ProvingSystem,
) -> Result<String, JsValue> {
    let decomposed_regex: DecomposedRegexConfig = serde_json::from_str(decomposedRegexJson)
        .map_err(|e| JsValue::from_str(&format!("Failed to parse decomposed regex: {}", e)))?;

    let (composed_regex, max_substring_bytes) = decomposed_to_composed_regex(&decomposed_regex);

    let circom_code = genFromRaw(
        &composed_regex,
        &max_substring_bytes,
        templateName,
        provingSystem,
    )
    .map_err(|e| JsValue::from_str(&format!("Failed to generate circom code: {:?}", e)))?;

    Ok(circom_code)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genFromRaw(
    rawRegex: &str,
    maxSubstringBytes: &[usize],
    templateName: &str,
    provingSystem: ProvingSystem,
) -> Result<String, JsValue> {
    let nfa = compile(rawRegex)
        .map_err(|e| JsValue::from_str(&format!("Failed to compile raw regex: {}", e)))?;

    let circom_code = match provingSystem {
        ProvingSystem::Circom => nfa
            .generate_circom_code(templateName, rawRegex, Some(maxSubstringBytes))
            .map_err(|e| JsValue::from_str(&format!("Failed to generate circom code: {}", e)))?,
        // TODO: Implement other proving systems
    };

    Ok(circom_code)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genCircuitInputs(
    regexGraphJson: &str,
    haystack: &str,
    maxHaystackLength: usize,
    maxMatchLength: usize,
    provingSystem: ProvingSystem,
) -> Result<String, JsValue> {
    let regex_graph: NFAGraph = serde_json::from_str(regexGraphJson)
        .map_err(|e| JsValue::from_str(&format!("Failed to parse regex graph: {}", e)))?;

    let inputs = match provingSystem {
        ProvingSystem::Circom => regex_graph
            .generate_circom_inputs(haystack, maxHaystackLength, maxMatchLength)
            .map_err(|e| JsValue::from_str(&format!("Failed to generate circom inputs: {}", e)))?,
        // TODO: Implement other proving systems
    };

    Ok(serde_json::to_string(&inputs)
        .map_err(|e| JsValue::from_str(&format!("Failed to serialize circom inputs: {}", e)))?)
}
