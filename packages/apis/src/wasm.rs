use crate::extract_substrs::*;
use crate::*;
use js_sys::Array;
use wasm_bindgen::prelude::*;

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
pub fn extractSubstrIdxes(inputStr: &str, regexConfig: JsValue) -> Array {
    let regex_config_str = regexConfig.as_string().unwrap();
    let regex_config: DecomposedRegexConfig = serde_json::from_str(&regex_config_str).unwrap();
    let public_idxes = extract_substrs::extract_substr_idxes(inputStr, &regex_config).unwrap();
    let arr = Array::new_with_length(public_idxes.len() as u32);
    for (i, idx) in public_idxes.iter().enumerate() {
        let js_arr = Array::new_with_length(2);
        js_arr.set(0, JsValue::from(idx.0 as u32));
        js_arr.set(1, JsValue::from(idx.1 as u32));
        arr.set(i as u32, JsValue::from(js_arr));
    }

    arr
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractEmailAddrIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/email_addr.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractEmailDomainIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/email_domain.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractEmailAddrWithNameIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/email_addr_with_name.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractFromAllIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/from_all.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractFromAddrIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/from_addr.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractToAllIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/to_all.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractToAddrIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/to_addr.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractSubjectAllIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/subject_all.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractBodyHashIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/body_hash.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractTimestampIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/timestamp.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
#[allow(non_snake_case)]
pub fn extractMessageIdIdxes(inputStr: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/message_id.json");
    extractSubstrIdxes(inputStr, JsValue::from_str(regex_config))
}
