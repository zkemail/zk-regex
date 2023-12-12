

use js_sandbox::{JsError, Script};

use serde_json::Value;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum JsCallerError {
    #[error("Edges {0} are not object")]
    InvalidEdges(Value),
    #[error("node value {0} is not u64")]
    InvalidNodeValue(Value),
    #[error("No accepted state")]
    NoAcceptedState,
    #[error(transparent)]
    JsError(#[from] JsError),
    #[error(transparent)]
    JsonError(#[from] serde_json::Error),
}

// pub fn catch_all_regex_str() -> Result<String, JsCallerError> {
//     let code: &'static str = include_str!("regex.js");
//     let mut script = Script::from_string(code)?;
//     let result: String = script.call("catchAllRegexStr", ())?;
//     Ok(result)
// }

pub fn text_context_prefix() -> Result<String, JsCallerError> {
    let code: &'static str = include_str!("regex.js");
    let mut script = Script::from_string(code)?;
    let result: String = script.call("textContextPrefix", ())?;
    Ok(result)
}

// pub fn format_regex_printable(regex: &str) -> Result<String, JsCallerError> {
//     let code: &'static str = include_str!("regex.js");
//     let mut script = Script::from_string(code)?;
//     let result: String = script.call("formatRegexPrintable", (regex,))?;
//     Ok(result)
// }

pub fn regex_to_dfa(regex: &str) -> Result<Vec<Value>, JsCallerError> {
    let code: &'static str = include_str!("regex.js");
    let mut script = Script::from_string(code)?;
    let result: String = script.call("regexToDfa", (regex,))?;
    Ok(serde_json::from_str(&result)?)
}

pub fn gen_circom_allstr(graph: &[Value], template_name: &str, regex_str: &str) -> Result<String, JsCallerError> {
    let code: &'static str = include_str!("gen_circom.js");
    let mut script = Script::from_string(code)?;
    let result: String = script.call("genCircomAllstr", (graph, template_name, regex_str))?;
    Ok(result)
}
