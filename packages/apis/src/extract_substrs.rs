use fancy_regex::Regex;
use compiler::{DecomposedRegexConfig};
use itertools::Itertools;
use neon::prelude::*;
use thiserror::Error;
use serde_json;

/// Error definitions of the compiler.
#[derive(Error, Debug)]
pub enum ExtractSubstrssError {
    #[error("The max length is {} but the input length is {}",.0,.1)]
    InvalidInputLen(usize, usize),
    #[error("Substring of the entire regex {} is not found in {}",.0,.1)]
    SubstringOfEntireNotFound(Regex,String),
    #[error("Substring of {} is not found in {}",.0,.1)]
    SubstringNotFound(Regex,String),
    #[error(transparent)]
    RegexError(#[from] fancy_regex::Error),
}


pub fn extract_substr_idxes(
    input_str: &str,
    regex_config: &DecomposedRegexConfig,
) -> Result<Vec<(usize,usize)>,ExtractSubstrssError> {
    if input_str.len() > regex_config.max_byte_size {
        return Err(ExtractSubstrssError::InvalidInputLen(regex_config.max_byte_size,input_str.len()));
    }
    let mut entire_regex_str = String::new();
    for part in regex_config.parts.iter() {
        entire_regex_str += part.regex_def.as_str();
    }
    // entire_regex_str = format_regex_printable(&entire_regex_str)?;
    let entire_regex = Regex::new(&entire_regex_str)?;
    let entire_found =  entire_regex.find(input_str)?.ok_or_else(|| {
        ExtractSubstrssError::SubstringOfEntireNotFound(entire_regex, input_str.to_string())
    })?;
    let mut start = entire_found.start();
    let entire_end = entire_found.end();

    let mut public_idxes = vec![];
    // let mut last_regex_str = String::new();
    // let part_regex_defs = regex_config.parts.iter().map(|part| part.regex_def.as_str()).collect_vec();
    for part_idx in 0..regex_config.parts.len() {
        // last_regex_str = last_regex_str + regex_config.parts[part_idx].regex_def.as_str();
        let regex = Regex::new(&regex_config.parts[part_idx].regex_def.as_str())?;
        let found = regex.find_from_pos(&input_str,start)?.ok_or_else(|| {
            ExtractSubstrssError::SubstringNotFound(regex.clone(), input_str[start..entire_end].to_string())
        })?;
        let end = found.end();
        // if found.start() >= end {
        //     return Err(ExtractSubstrssError::EmptySubstring(regex, input_str[start..entire_end].to_string()));
        // }
        if regex_config.parts[part_idx].is_public {
            public_idxes.push((start,end));
        }
        start = end;
    }

    Ok(public_idxes)
}

pub fn extract_substr_idxes_node(
    mut cx: FunctionContext
) -> JsResult<JsArray> {
    let input_str = cx.argument::<JsString>(0)?.value(&mut cx);
    let regex_config_str = cx.argument::<JsString>(1)?.value(&mut cx);
    let regex_config = match  serde_json::from_str::<DecomposedRegexConfig>(&regex_config_str){
        Ok(regex_config) => regex_config,
        Err(e) => return cx.throw_error(e.to_string())
    };
    let substr_idxes = match extract_substr_idxes(&input_str, &regex_config){
        Ok(substr_idxes) => substr_idxes,
        Err(e) => return cx.throw_error(e.to_string())
    };
    let js_array = JsArray::new(&mut cx, substr_idxes.len() as u32);
    for (i, (start_idx,end_idx)) in substr_idxes.iter().enumerate() {
        let start_end_array = JsArray::new(&mut cx,2u32);
        let start_idx = cx.number(*start_idx as f64);
        start_end_array.set(&mut cx, 0, start_idx)?;
        let end_idx = cx.number(*end_idx as f64);
        start_end_array.set(&mut cx, 1, end_idx)?;
        js_array.set(&mut cx, i as u32, start_end_array)?;
    }
    Ok(js_array)
}



#[cfg(test)]
mod test {
    use compiler::RegexPartConfig;

    use super::*;

    #[test]
    fn test_email_domain_valid() {
        let email_addr_regex = DecomposedRegexConfig {
            max_byte_size: 256,
            parts: vec![
                RegexPartConfig {
                    is_public: false,
                    regex_def: "(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|\\.|_|%|\\+|-|=)+".to_string(),
                    max_size: 64,
                    solidity: None
                },
                RegexPartConfig {
                    is_public: false,
                    regex_def: "@".to_string(),
                    max_size: 1,
                    solidity: None
                },
                RegexPartConfig {
                    is_public: true, 
                    regex_def: "(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|\\.|-)+".to_string(),
                    max_size: 255,
                    solidity: None
                }
            ]
        };
        let input_str = "suegamisora@gmail.com";
        let idxes = extract_substr_idxes(input_str, &email_addr_regex).unwrap();
        assert_eq!(idxes, vec![(12,21)]);
    }


    #[test]
    fn test_email_addr_in_subject_valid() {
        let email_addr_regex = DecomposedRegexConfig {
            max_byte_size: 256,
            parts: vec![
                RegexPartConfig {
                    is_public: true,
                    regex_def: "(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|\\.|_|%|\\+|-|=)+".to_string(),
                    max_size: 64,
                    solidity: None
                },
                RegexPartConfig {
                    is_public: true,
                    regex_def: "@".to_string(),
                    max_size: 1,
                    solidity: None
                },
                RegexPartConfig {
                    is_public: true, 
                    regex_def: "(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|\\.|-)+".to_string(),
                    max_size: 255,
                    solidity: None
                }
            ]
        };
        let input_str = "This is sent for suegamisora@gmail.com";
        let idxes = extract_substr_idxes(input_str, &email_addr_regex).unwrap();
        assert_eq!(idxes, vec![(17, 28),(28,29),(29, 38)]);
    }

    #[test]
    fn test_code_in_subject_valid() {
        let code_regex = DecomposedRegexConfig {
            max_byte_size: 1024,
            parts: vec![
                RegexPartConfig {
                    is_public: false,
                    regex_def: "CODE:0x".to_string(),
                    max_size: 7,
                    solidity: None
                },
                RegexPartConfig {
                    is_public: true,
                    regex_def: "(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f)+".to_string(),
                    max_size: 6,
                    solidity: None
                }
            ]
        };
        let input_str = "subject: Email Wallet CODE:0x123abc";
        let idxes = extract_substr_idxes(input_str, &code_regex).unwrap();
        assert_eq!(idxes, vec![(29, 35)]);
    }

    #[test]
    fn test_timestamp_valid() {
        let timestamp_regex = DecomposedRegexConfig {
            max_byte_size: 1024,
            parts: vec![
                RegexPartConfig {
                    is_public: false,
                    regex_def: "dkim-signature:".to_string(),
                    max_size: 10,
                    solidity: None
                },
                RegexPartConfig {
                    is_public: false,
                    regex_def: "((a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z)+=(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|!|\"|#|$|%|&|\'|\\(|\\)|\\*|\\+|,|-|\\.|\\/|:|<|=|>|\\?|@|\\[|\\\\|\\]|\\^|_|`|{|\\||}|~| |\t|\n|\r|\\x0b|\\x0c)+; )+t=".to_string(),
                    max_size: 128,
                    solidity: None
                },
                RegexPartConfig {
                    is_public: true,
                    regex_def: "(0|1|2|3|4|5|6|7|8|9)+".to_string(),
                    max_size: 10,
                    solidity: None
                },
                RegexPartConfig {
                    is_public: false,
                    regex_def: ";".to_string(),
                    max_size: 1,
                    solidity: None
                },
            ]
        };
        let input_str = "dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=";
        let idxes = extract_substr_idxes(input_str, &timestamp_regex).unwrap();
        assert_eq!(idxes, vec![(80, 90)]);
    }
}
