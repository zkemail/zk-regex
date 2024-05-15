use crate::*;
use serde_wasm_bindgen::from_value;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genFromDecomposed(decomposedRegexJson: &str, circomTemplateName: &str) -> String {
    let mut decomposed_regex_config: DecomposedRegexConfig =
        serde_json::from_str(decomposedRegexJson).expect("failed to parse decomposed_regex json");
    let regex_and_dfa = decomposed_regex_config
        .to_regex_and_dfa()
        .expect("failed to convert the decomposed regex to dfa");
    regex_and_dfa
        .gen_circom_str(&circomTemplateName)
        .expect("failed to generate circom")
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genFromRaw(rawRegex: &str, substrsJson: &str, circomTemplateName: &str) -> String {
    let substrs_defs_json: SubstrsDefsJson =
        serde_json::from_str(substrsJson).expect("failed to parse substrs json");
    let regex_and_dfa = RegexAndDFA::from_regex_str_and_substr_defs(rawRegex, substrs_defs_json)
        .expect("failed to convert the raw regex and state transitions to dfa");
    regex_and_dfa
        .gen_circom_str(&circomTemplateName)
        .expect("failed to generate circom")
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genRegexAndDfa(decomposedRegex: JsValue) -> JsValue {
    let mut decomposed_regex_config: DecomposedRegexConfig = from_value(decomposedRegex).unwrap();
    let regex_and_dfa = regex_and_dfa(&mut decomposed_regex_config);
    let dfa_val_str = serde_json::to_string(&regex_and_dfa).unwrap();
    JsValue::from_str(&dfa_val_str)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn genCircom(decomposedRegex: JsValue, circomTemplateName: &str) -> String {
    let mut decomposed_regex_config: DecomposedRegexConfig = from_value(decomposedRegex).unwrap();
    let regex_and_dfa = regex_and_dfa(&mut decomposed_regex_config);
    regex_and_dfa
        .gen_circom_str(&circomTemplateName)
        .expect("failed to generate circom")
}
