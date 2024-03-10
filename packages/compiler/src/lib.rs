use std::fs::File;
use std::iter::FromIterator;
pub mod circom;
pub mod halo2;
pub mod regex;

// #[cfg(test)]
// mod tests;

use crate::regex::*;

use itertools::Itertools;
use petgraph::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;
use thiserror::Error;

use wasm_bindgen::prelude::*;


/// Error definitions of the compiler.
#[derive(Error, Debug)]
pub enum CompilerError {
    #[error("No edge from {:?} to {:?} in the graph",.0,.1)]
    NoEdge(NodeIndex<usize>, NodeIndex<usize>),
    #[error(transparent)]
    IoError(#[from] std::io::Error),
    #[error(transparent)]
    RegexError(#[from] fancy_regex::Error),
}

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
/// Solidity type of the substring.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum SoldityType {
    String,
    Uint,
    Decimal,
}

#[derive(Debug, Clone)]
pub struct DFAState {
    r#type: String,
    state: usize,
    edges: BTreeMap<usize, BTreeSet<u8>>,
}

#[derive(Debug, Clone)]
pub struct DFAGraph {
    states: Vec<DFAState>,
}

#[derive(Debug, Clone)]
pub struct RegexAndDFA {
    // pub max_byte_size: usize,
    // Original regex string, only here to be printed in generated file to make it more reproducible
    pub regex_str: String,
    pub dfa_val: DFAGraph,
    pub substrs_defs: SubstrsDefs,
}

#[derive(Debug, Clone)]
pub struct SubstrsDefs {
    pub substr_defs_array: Vec<BTreeSet<(usize, usize)>>,
    pub substr_endpoints_array: Option<Vec<(BTreeSet<usize>, BTreeSet<usize>)>>,
    // pub max_bytes: Option<Vec<usize>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstrsDefsJson {
    pub transitions: Vec<Vec<(usize, usize)>>,
}

impl DecomposedRegexConfig {
    pub fn to_regex_and_dfa(&self) -> Result<RegexAndDFA, CompilerError> {
        Ok(regex_and_dfa(self))
    }
}

impl RegexAndDFA {
    pub fn from_regex_str_and_substr_defs(
        // max_byte_size: usize,
        regex_str: &str,
        substrs_defs_json: SubstrsDefsJson,
    ) -> Result<RegexAndDFA, CompilerError> {
        let dfa_val = dfa_from_regex_str(regex_str);
        let substr_defs_array = substrs_defs_json
            .transitions
            .into_iter()
            .map(|transitions_array| BTreeSet::<(usize, usize)>::from_iter(transitions_array))
            .collect_vec();
        let substrs_defs = SubstrsDefs {
            substr_defs_array,
            substr_endpoints_array: None,
            // max_bytes: None,
        };

        Ok(RegexAndDFA {
            // max_byte_size,
            regex_str: regex_str.to_string(),
            dfa_val,
            substrs_defs,
        })
    }
}

pub fn gen_from_decomposed(
    decomposed_regex_path: &str,
    // halo2_dir_path: Option<&str>,
    circom_file_path: Option<&str>,
    circom_template_name: Option<&str>,
    gen_substrs: Option<bool>,
) {
    let decomposed_regex_config: DecomposedRegexConfig =
        serde_json::from_reader(File::open(decomposed_regex_path).unwrap()).unwrap();
    let regex_and_dfa = decomposed_regex_config
        .to_regex_and_dfa()
        .expect("failed to convert the decomposed regex to dfa");
    let gen_substrs = gen_substrs.unwrap_or(true);
    // if let Some(halo2_dir_path) = halo2_dir_path {
    //     let halo2_dir_path = PathBuf::from(halo2_dir_path);
    //     let allstr_file_path = halo2_dir_path.join("allstr.txt");
    //     let mut num_public_parts = 0usize;
    //     for part in decomposed_regex_config.parts.iter() {
    //         if part.is_public {
    //             num_public_parts += 1;
    //         }
    //     }
    //     let substr_file_paths = (0..num_public_parts)
    //         .map(|idx| halo2_dir_path.join(format!("substr_{}.txt", idx)))
    //         .collect_vec();
    //     regex_and_dfa
    //         .gen_halo2_tables(&allstr_file_path, &substr_file_paths, gen_substrs)
    //         .expect("failed to generate halo2 tables");
    // }
    if let Some(circom_file_path) = circom_file_path {
        let circom_file_path = PathBuf::from(circom_file_path);
        let circom_template_name = circom_template_name
            .expect("circom template name must be specified if circom file path is specified");
        regex_and_dfa
            .gen_circom(&circom_file_path, &circom_template_name, gen_substrs)
            .expect("failed to generate circom");
    }
}


#[wasm_bindgen]
extern {
    pub fn alert(s: &str);
}


#[wasm_bindgen]
pub fn greet(name: &str) {
    alert(&format!("Hello POE, {}!", name));
}


pub fn gen_from_raw(
    raw_regex: &str,
    // max_bytes: usize,
    substrs_json_path: Option<&str>,
    // halo2_dir_path: Option<&str>,
    circom_file_path: Option<&str>,
    template_name: Option<&str>,
    gen_substrs: Option<bool>,
) {
    let substrs_defs_json = if let Some(substrs_json_path) = substrs_json_path {
        let substrs_json_path = PathBuf::from(substrs_json_path);
        let substrs_defs_json: SubstrsDefsJson =
            serde_json::from_reader(File::open(substrs_json_path).unwrap()).unwrap();
        substrs_defs_json
    } else {
        SubstrsDefsJson {
            transitions: vec![vec![]],
        }
    };
    // let num_public_parts = substrs_defs_json.transitions.len();
    let regex_and_dfa = RegexAndDFA::from_regex_str_and_substr_defs(raw_regex, substrs_defs_json)
        .expect("failed to convert the raw regex and state transitions to dfa");
    let gen_substrs = gen_substrs.unwrap_or(true);
    // if let Some(halo2_dir_path) = halo2_dir_path {
    //     let halo2_dir_path = PathBuf::from(halo2_dir_path);
    //     let allstr_file_path = halo2_dir_path.join("allstr.txt");
    //     let substr_file_paths = (0..num_public_parts)
    //         .map(|idx| halo2_dir_path.join(format!("substr_{}.txt", idx)))
    //         .collect_vec();
    //     regex_and_dfa
    //         .gen_halo2_tables(&allstr_file_path, &substr_file_paths, gen_substrs)
    //         .expect("failed to generate halo2 tables");
    // }
    if let Some(circom_file_path) = circom_file_path {
        let circom_file_path = PathBuf::from(circom_file_path);
        let template_name = template_name
            .expect("circom template name must be specified if circom file path is specified");
        regex_and_dfa
            .gen_circom(&circom_file_path, &template_name, gen_substrs)
            .expect("failed to generate circom");
    }
}

pub(crate) fn get_accepted_state(dfa_val: &DFAGraph) -> Option<usize> {
    for i in 0..dfa_val.states.len() {
        if dfa_val.states[i].r#type == "accept" {
            return Some(i as usize);
        }
    }
    None
}

// pub(crate) fn get_max_state(dfa_val: &DFAGraph) -> usize {
//     let mut max_state = 0;
//     for (_i, val) in dfa_val.states.iter().enumerate() {
//         if val.state > max_state {
//             max_state = val.state;
//         }
//     }
//     max_state
// }

#[cfg(feature = "export_neon_main")]
#[neon::main]
fn main(mut cx: neon::prelude::ModuleContext) -> neon::prelude::NeonResult<()> {
    cx.export_function("genFromDecomposed", gen_from_decomposed_node)?;
    cx.export_function("genFromRaw", gen_from_raw_node)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gen_from_decomposed() {
        let project_root = PathBuf::new().join(env!("CARGO_MANIFEST_DIR"));
        let decomposed_regex_path = project_root.join("../circom/circuits/common/subject_all.json");
        let circom_file_path =
            project_root.join("../circom/circuits/common/subject_all_regex.circom");
        let circom_template_name = Some("SubjectAllRegex");
        let gen_substrs = Some(true);

        let _result = gen_from_decomposed(
            decomposed_regex_path.to_str().unwrap(),
            Some(circom_file_path.to_str().unwrap()),
            circom_template_name.map(|s| s),
            gen_substrs,
        );
    }
}
