use crate::extract_substrs::*;
use crate::*;
use console_error_panic_hook;
use js_sys::Array;
use serde_json::Value;
use std::panic;
use wasm_bindgen::prelude::*;

#[wasm_bindgen(start)]
pub fn init_panic_hook() {
    panic::set_hook(Box::new(console_error_panic_hook::hook));
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn padString(str: &str, paddedBytesSize: usize) -> Array {
    let padded_bytes = padding::pad_string(str, paddedBytesSize);

    let arr = Array::new_with_length(padded_bytes.len() as u32);
    for (i, byte) in padded_bytes.iter().enumerate() {
        arr.set(i as u32, JsValue::from(*byte));
    }

    arr
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractSubstrIdxes(
    inputStr: &str,
    regexConfig: JsValue,
    reveal_private: bool,
) -> Result<Array, JsValue> {
    let regex_config = parse_js_regex_config(regexConfig)?;

    let idxes = extract_substrs::extract_substr_idxes(inputStr, &regex_config, reveal_private)
        .map_err(|e| {
            println!("e: {:?}", e);
            let error_msg = format!("Failed to extract indxes: {}", e);
            JsValue::from_str(&error_msg)
        })?;

    let arr = Array::new_with_length(idxes.len() as u32);
    for (i, idx) in idxes.iter().enumerate() {
        let js_arr = Array::new_with_length(2);
        js_arr.set(0, JsValue::from(idx.0 as u32));
        js_arr.set(1, JsValue::from(idx.1 as u32));
        arr.set(i as u32, JsValue::from(js_arr));
    }

    Ok(arr)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractSubstr(
    inputStr: &str,
    regexConfig: JsValue,
    reveal_private: bool,
) -> Result<Array, JsValue> {
    let regex_config = parse_js_regex_config(regexConfig)?;

    let result_strs = extract_substrs::extract_substr(inputStr, &regex_config, reveal_private)
        .map_err(|e| {
            println!("e: {:?}", e);
            let error_msg = format!("Failed to extract strings: {}", e);
            JsValue::from_str(&error_msg)
        })?;

    let js_array = Array::new_with_length(result_strs.len() as u32);
    for (i, s) in result_strs.into_iter().enumerate() {
        js_array.set(i as u32, JsValue::from_str(&s));
    }

    Ok(js_array)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractEmailAddrIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/email_addr.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractEmailDomainIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/email_domain.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

// #[wasm_bindgen]
// #[allow(non_snake_case)]
// pub fn extractEmailAddrWithNameIdxes(inputStr: &str) -> Array {
//     let regex_config = include_str!("./decomposed_defs/email_addr_with_name.json");
//     extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
// }

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractFromAllIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/from_all.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractFromAddrIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/from_addr.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractToAllIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/to_all.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractToAddrIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/to_addr.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractSubjectAllIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/subject_all.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractBodyHashIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/body_hash.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractTimestampIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/timestamp.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractMessageIdIdxes(inputStr: &str) -> Result<Array, JsValue> {
    let regex_config = include_str!("./decomposed_defs/message_id.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config), false)
}

// Accepts regexConfig either as string or js object
fn parse_js_regex_config(regex_config: JsValue) -> Result<DecomposedRegexConfig, JsValue> {
    // Checks if regexConfig is passed as string or object
    // As string
    let parsed_config: DecomposedRegexConfig = if regex_config.is_string() {
        let config_str = regex_config.as_string().unwrap();
        serde_json::from_str(&config_str).map_err(|e| {
            let error_msg = format!("Failed to parse JSON string: {}", e);
            JsValue::from_str(&error_msg)
        })?
    // As object
    } else {
        serde_wasm_bindgen::from_value(regex_config).map_err(|e| {
            let error_msg = simplify_error(&e);
            JsValue::from_str(&error_msg)
        })?
    };

    Ok(parsed_config)
}

fn simplify_error(e: &serde_wasm_bindgen::Error) -> String {
    let error_string = e.to_string();
    if let Some(json_error) = serde_json::from_str::<Value>(&error_string).ok() {
        if let Some(message) = json_error["message"].as_str() {
            return message.to_string();
        }
    }
    error_string
}
