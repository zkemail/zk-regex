use fancy_regex::Regex;
use js_sys::Array;
use serde::{Deserialize, Serialize};

use serde_wasm_bindgen::from_value;
use thiserror::Error;
use wasm_bindgen::prelude::*;
use wasm_bindgen_test::*;

/// A configuration of decomposed regexes.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecomposedRegexConfig {
    pub parts: Vec<RegexPartConfig>,
}

/// Decomposed regex part.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegexPartConfig {
    /// A flag indicating whether the substring matching with `regex_def` should be exposed.
    pub is_public: bool,
    /// A regex string.
    pub regex_def: String,
    // Maximum byte size of the substring in this part.
    // pub max_size: usize,
    // (Optional) A solidity type of the substring in this part, e.g., "String", "Int", "Decimal".
    // pub solidity: Option<SoldityType>,
}

/// Error definitions of the compiler.
#[derive(Error, Debug)]
pub enum ExtractSubstrssError {
    // #[error("The max length is {} but the input length is {}",.0,.1)]
    // InvalidInputLen(usize, usize),
    #[error("Substring of the entire regex {} is not found in {}",.0,.1)]
    SubstringOfEntireNotFound(Regex, String),
    #[error("Substring of {} is not found in {}",.0,.1)]
    SubstringNotFound(Regex, String),
    #[error(transparent)]
    RegexError(#[from] fancy_regex::Error),
}

#[wasm_bindgen]
pub fn extract_substr_idxes(input_str: &str, regex_config: JsValue) -> Array {
    let regex_config_str = regex_config.as_string().unwrap();
    let regex_config: DecomposedRegexConfig = serde_json::from_str(&regex_config_str).unwrap();
    let mut entire_regex_str = String::new();
    for part in regex_config.parts.iter() {
        entire_regex_str += part.regex_def.as_str();
    }

    let entire_regex = Regex::new(&entire_regex_str).unwrap();
    let entire_found = entire_regex
        .find(input_str)
        .unwrap()
        .ok_or_else(|| {
            ExtractSubstrssError::SubstringOfEntireNotFound(entire_regex, input_str.to_string())
        })
        .unwrap();
    let mut start = entire_found.start();
    let entire_end = entire_found.end();

    let mut public_idxes = vec![];

    for part_idx in 0..regex_config.parts.len() {
        // last_regex_str = last_regex_str + regex_config.parts[part_idx].regex_def.as_str();
        let regex = Regex::new(&regex_config.parts[part_idx].regex_def.as_str()).unwrap();
        let found = regex
            .find_from_pos(&input_str, start)
            .unwrap()
            .ok_or_else(|| {
                ExtractSubstrssError::SubstringNotFound(
                    regex.clone(),
                    input_str[start..entire_end].to_string(),
                )
            })
            .unwrap();
        let end = found.end();

        if regex_config.parts[part_idx].is_public {
            public_idxes.push((start, end));
        }
        start = end;
    }

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
pub fn extract_email_addr_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/email_addr.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_email_domain_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/email_domain.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_email_addr_with_name_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/email_addr_with_name.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_from_all_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/from_all.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_from_addr_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/from_addr.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_to_all_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/to_all.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_to_addr_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/to_addr.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_subject_all_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/subject_all.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_body_hash_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/body_hash.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_timestamp_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/timestamp.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[wasm_bindgen]
pub fn extract_message_id_idxes(input_str: &str) -> Array {
    let regex_config = include_str!("./decomposed_defs/message_id.json");
    extract_substr_idxes(input_str, JsValue::from_str(regex_config))
}

#[cfg(test)]
mod test {
    use super::*;

    #[wasm_bindgen_test]
    fn test_email_domain_valid() {
        let input_str = "suegamisora@gmail.com";
        let idxes = extract_email_domain_idxes(input_str);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![12, 21]);
    }

    #[wasm_bindgen_test]
    fn test_email_addr_in_subject_valid() {
        let input_str = "This is sent for suegamisora@gmail.com";
        let idxes = extract_email_addr_idxes(input_str);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![17, 38]);
    }

    #[wasm_bindgen_test]
    fn test_email_addr_with_name_valid1() {
        let input_str = "from:dummy@a.com <suegamisora@gmail.com>";
        let idxes = extract_email_addr_with_name_idxes(input_str);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![18, 39]);
    }

    #[wasm_bindgen_test]
    fn test_email_addr_with_name_valid2() {
        // "末神 奏宙" has 13 bytes.
        let input_str = "from:\"末神 奏宙\" <suegamisora@gmail.com>";
        let idxes = extract_email_addr_with_name_idxes(input_str);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![22, 43]);
    }

    #[wasm_bindgen_test]
    fn test_email_from_all_valid() {
        let input_str = "from:dummy@a.com <suegamisora@gmail.com>\r\n";
        let idxes = extract_from_all_idxes(input_str);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![5, 40]);
    }

    #[wasm_bindgen_test]
    fn test_email_from_addr_valid() {
        let input_str = "from:dummy@a.com <suegamisora@gmail.com>\r\n";
        let idxes = extract_from_addr_idxes(input_str);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![18, 39]);
    }

    #[wasm_bindgen_test]
    fn test_code_in_email_address_valid() {
        let code_regex = DecomposedRegexConfig {
            // max_byte_size: 1024,
            parts: vec![
                RegexPartConfig {
                    is_public: false,
                    regex_def: "ACCOUNTKEY.0x".to_string(),
                    // max_size: 7,
                    // solidity: None
                },
                RegexPartConfig {
                    is_public: true,
                    regex_def: "(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f)+".to_string(),
                    // max_size: 6,
                    // solidity: None
                },
            ],
        };
        let input_str = "sepolia+ACCOUNTKEY.0xabc123@sendeth.org";
        let code_regex = JsValue::from_str(&serde_json::to_string(&code_regex).unwrap());
        let idxes = extract_substr_idxes(input_str, code_regex);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![21, 27]);
    }

    #[wasm_bindgen_test]
    fn test_body_hash_valid() {
        let input_str = "dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=";
        let idxes = extract_body_hash_idxes(input_str);
        assert_eq!(from_value::<Vec<u32>>(idxes.at(0)).unwrap(), vec![219, 263]);
    }

    #[wasm_bindgen_test]
    fn test_timestamp_valid() {
        let input_str = "dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=";
        let idxes = extract_timestamp_idxes(input_str);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![80, 90]);
    }

    #[wasm_bindgen_test]
    fn test_message_id_valid() {
        let input_str =
            "message-id:<CAJ7Y6jerCWt6t4HVqfXeeqRthJpj_1vYCpXzAVgowozVFKWbVQ@mail.gmail.com>\r\n";
        let idxes = extract_message_id_idxes(input_str);
        assert_eq!(from_value::<Vec<u8>>(idxes.at(0)).unwrap(), vec![11, 79]);
    }
}
