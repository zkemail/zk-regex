use crate::*;
use console_error_panic_hook;
use serde_wasm_bindgen::from_value;
use std::panic;
use wasm_bindgen::prelude::*;

use self::circom::gen_circom_string;

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genFromDecomposed(
    decomposedRegexJson: &str,
    circomTemplateName: &str,
) -> Result<String, JsValue> {
    let mut decomposed_regex_config: DecomposedRegexConfig =
        serde_json::from_str(decomposedRegexJson).map_err(|e| {
            JsValue::from_str(&format!("failed to parse decomposed_regex json: {}", e))
        })?;

    let regex_and_dfa = get_regex_and_dfa(&mut decomposed_regex_config).map_err(|e| {
        JsValue::from_str(&format!(
            "failed to convert the decomposed regex to dfa: {}",
            e
        ))
    })?;

    gen_circom_string(&regex_and_dfa, circomTemplateName)
        .map_err(|e| JsValue::from_str(&format!("Failed to generate Circom string: {}", e)))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genFromRaw(rawRegex: &str, substrsJson: &str, circomTemplateName: &str) -> String {
    let substrs_defs_json: SubstringDefinitionsJson =
        serde_json::from_str(substrsJson).expect("failed to parse substrs json");
    let regex_and_dfa = create_regex_and_dfa_from_str_and_defs(rawRegex, substrs_defs_json)
        .expect("failed to convert the raw regex and state transitions to dfa");
    gen_circom_string(&regex_and_dfa, circomTemplateName).expect("failed to generate circom")
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genRegexAndDfa(decomposedRegex: JsValue) -> JsValue {
    let mut decomposed_regex_config: DecomposedRegexConfig =
        from_value(decomposedRegex).expect("failed to parse decomposed regex");
    let regex_and_dfa = get_regex_and_dfa(&mut decomposed_regex_config)
        .expect("failed to convert the decomposed regex to dfa");
    let dfa_val_str =
        serde_json::to_string(&regex_and_dfa).expect("failed to convert the dfa to json");
    JsValue::from_str(&dfa_val_str)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genCircom(decomposedRegex: JsValue, circomTemplateName: &str) -> String {
    let mut decomposed_regex_config: DecomposedRegexConfig =
        from_value(decomposedRegex).expect("failed to parse decomposed regex");
    let regex_and_dfa = get_regex_and_dfa(&mut decomposed_regex_config)
        .expect("failed to convert the decomposed regex to dfa");
    gen_circom_string(&regex_and_dfa, circomTemplateName).expect("failed to generate circom")
}
