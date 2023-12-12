use std::iter::FromIterator;
use std::{collections::HashMap, fs::File};
pub mod circom;
pub mod halo2;
pub mod js_caller;

pub mod node;

// #[cfg(test)]
// mod tests;

use crate::node::*;
use neon;

use crate::js_caller::*;
use fancy_regex::Regex;
use itertools::Itertools;
use petgraph::prelude::*;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashSet;
use std::path::PathBuf;
use thiserror::Error;

/// Error definitions of the compiler.
#[derive(Error, Debug)]
pub enum CompilerError {
    #[error("No edge from {:?} to {:?} in the graph",.0,.1)]
    NoEdge(NodeIndex<usize>, NodeIndex<usize>),
    #[error(transparent)]
    JsCallerError(#[from] JsCallerError),
    #[error(transparent)]
    IoError(#[from] std::io::Error),
    #[error(transparent)]
    RegexError(#[from] fancy_regex::Error),
}

/// A configuration of decomposed regexes.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecomposedRegexConfig {
    /// Maximum byte size of the input string.
    // pub max_byte_size: usize,
    /// A vector of decomposed regexes.
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
pub struct RegexAndDFA {
    // pub max_byte_size: usize,
    // Original regex string, only here to be printed in generated file to make it more reproducible
    pub regex_str: String, 
    pub dfa_val: Vec<Value>,
    pub substrs_defs: SubstrsDefs,
}

#[derive(Debug, Clone)]
pub struct SubstrsDefs {
    pub substr_defs_array: Vec<HashSet<(usize, usize)>>,
    pub substr_endpoints_array: Option<Vec<(HashSet<usize>, HashSet<usize>)>>,
    // pub max_bytes: Option<Vec<usize>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstrsDefsJson {
    pub transitions: Vec<Vec<(usize, usize)>>,
}

impl DecomposedRegexConfig {
    pub fn to_regex_and_dfa(&self) -> Result<RegexAndDFA, CompilerError> {
        let mut all_regex = String::new();
        let part_configs = &self.parts;
        for config in part_configs.iter() {
            all_regex += &config.regex_def;
        }
        let dfa_val = regex_to_dfa(&all_regex)?;
        // println!("dfa_val {:?}", dfa_val);
        let substrs_defs = self.extract_substr_ids(&dfa_val)?;
        Ok(RegexAndDFA {
            // max_byte_size: self.max_byte_size,
            regex_str: all_regex,
            dfa_val,
            substrs_defs,
        })
    }

    pub fn extract_substr_ids(&self, dfa_val: &[Value]) -> Result<SubstrsDefs, CompilerError> {
        let part_configs = &self.parts;
        let mut graph = Graph::<bool, char, Directed, usize>::with_capacity(0, 0);
        let max_state = get_max_state(dfa_val)?;
        add_graph_nodes(dfa_val, &mut graph, None, max_state)?;
        let accepted_state = get_accepted_state(dfa_val).ok_or(JsCallerError::NoAcceptedState)?;
        let accepted_state_index = NodeIndex::from(accepted_state);
        let mut pathes = Vec::<Vec<NodeIndex<usize>>>::new();
        let mut stack = Vec::<(NodeIndex<usize>, Vec<NodeIndex<usize>>)>::new();
        stack.push((accepted_state_index, vec![accepted_state_index]));
        let mut self_nodes = HashSet::new();
        let mut self_nodes_char = HashMap::new();
        for state in 0..=max_state {
            let node = NodeIndex::from(state);
            if let Some(edge) = graph.find_edge(node, node) {
                let str = graph.edge_weight(edge).unwrap().to_string();
                let bytes = str.as_bytes();
                self_nodes_char.insert(node.index(), bytes[0]);
            }
        }

        while stack.len() != 0 {
            let (node, path) = stack.pop().unwrap();
            let mut parents = graph.neighbors(node).detach();
            while let Some((edge, parent)) = parents.next(&graph) {
                if parent.index() == node.index() {
                    self_nodes.insert(node.index());
                    graph.remove_edge(edge).unwrap();
                    continue;
                }
                if !path.contains(&parent) {
                    if parent.index() == 0 {
                        pathes.push(path.to_vec());
                        continue;
                    }
                    stack.push((parent, vec![path.clone(), vec![parent]].concat()));
                }
            }
        }

        let mut public_config_indexes: Vec<usize> = vec![];
        let mut part_regexes = vec![];
        for (idx, config) in part_configs.iter().enumerate() {
            if config.is_public {
                public_config_indexes.push(idx);
            }
            let mut this_regex = config.regex_def.to_string();
            if let Some(mut idx) = this_regex.find("[^") {
                let mut new_regex = this_regex[0..idx].to_string();
                new_regex += "[";
                idx += 2;
                let end = this_regex.find("]").unwrap();
                let mut chars_in_brancket = vec![];
                while idx < end {
                    let char = this_regex.chars().nth(idx).unwrap();
                    if char == '\\' {
                        chars_in_brancket
                            .push(format!("\\{}", this_regex.chars().nth(idx + 1).unwrap()));
                        idx += 2;
                    } else {
                        chars_in_brancket.push(char.to_string());
                        idx += 1;
                    }
                }
                for code in 0..255 {
                    let code_char = char::from_u32(code).unwrap();
                    let mut code_str = code_char.to_string();
                    if [
                        '(', ')', '*', '+', '.', '?', '[', '\\', ']', '^', '`', '|', '-',
                    ]
                    .contains(&code_char)
                    {
                        code_str = format!("\\{}", code_char);
                    }
                    if chars_in_brancket.contains(&code_str) {
                        continue;
                    }
                    new_regex += &code_str;
                }
                new_regex += &this_regex[end..].to_string();
                this_regex = new_regex;
            }
            this_regex = this_regex.replace("^", "\\^");
            if idx == 0 {
                part_regexes.push(Regex::new(&this_regex)?);
            } else {
                let pre_regex = part_regexes[idx - 1].to_string();
                part_regexes.push(Regex::new(&(pre_regex + &this_regex))?);
            }
        }
        let num_public_parts = public_config_indexes.len();
        let mut substr_defs_array = (0..num_public_parts)
            .map(|_| HashSet::<(usize, usize)>::new())
            .collect_vec();
        let mut substr_endpoints_array = (0..num_public_parts)
            .map(|_| (HashSet::<usize>::new(), HashSet::<usize>::new()))
            .collect_vec();
        for path in pathes.iter_mut() {
            let n = path.len();
            path.append(&mut vec![NodeIndex::from(0)]);
            let edges = (0..n)
                .map(|idx| {
                    graph
                        .find_edge(path[idx], path[idx + 1])
                        .ok_or(CompilerError::NoEdge(path[idx], path[idx + 1]))
                })
                .collect::<Result<Vec<EdgeIndex<usize>>, CompilerError>>()?;
            let string_vec = edges
                .iter()
                .map(|edge| graph.edge_weight(*edge).unwrap().to_string())
                .collect::<Vec<String>>();
            let path_states = path
                .into_iter()
                .rev()
                .map(|node| node.index())
                .collect::<Vec<usize>>();
            let path_strs = string_vec
                .iter()
                .rev()
                .map(|s| s.to_string())
                .collect::<Vec<String>>();
            let substr_states = self.get_substr_defs_from_path(
                &path_states,
                &path_strs,
                &part_regexes,
                &public_config_indexes,
            )?;
            for (substr_idx, (path_states, substr)) in substr_states.into_iter().enumerate() {
                let defs = &mut substr_defs_array[substr_idx];
                substr_endpoints_array[substr_idx].0.insert(path_states[0]);
                substr_endpoints_array[substr_idx]
                    .1
                    .insert(path_states[path_states.len() - 1]);
                for path_idx in 0..(path_states.len() - 1) {
                    defs.insert((path_states[path_idx], path_states[path_idx + 1]));
                    if self_nodes.contains(&path_states[path_idx]) {
                        defs.insert((path_states[path_idx], path_states[path_idx]));
                    }
                    for pre_path_idx in 0..=path_idx {
                        if graph
                            .find_edge(
                                NodeIndex::from(path_states[pre_path_idx]),
                                NodeIndex::from(path_states[path_idx + 1]),
                            )
                            .is_some()
                        {
                            defs.insert((path_states[path_idx + 1], path_states[pre_path_idx]));
                        }
                    }
                }
                if self_nodes.contains(&path_states[path_states.len() - 1]) {
                    let part_index = public_config_indexes[substr_idx];
                    let part_regex = &part_regexes[part_index];
                    let byte = self_nodes_char[&path_states[path_states.len() - 1]];
                    let substr = substr + &(byte as char).to_string();
                    if part_regex.is_match(&substr).unwrap() {
                        defs.insert((
                            path_states[path_states.len() - 1],
                            path_states[path_states.len() - 1],
                        ));
                    }
                }
            }
        }
        // let max_bytes = public_config_indexes
        //     .iter()
        //     .map(|idx| self.parts[*idx].max_size)
        //     .collect_vec();
        let substrs_defs = SubstrsDefs {
            substr_defs_array,
            substr_endpoints_array: Some(substr_endpoints_array),
            // max_bytes: Some(max_bytes),
        };
        Ok(substrs_defs)
    }

    fn get_substr_defs_from_path(
        &self,
        path_states: &[usize],
        path_strs: &[String],
        part_regexes: &[Regex],
        public_config_indexes: &[usize],
    ) -> Result<Vec<(Vec<usize>, String)>, CompilerError> {
        debug_assert_eq!(path_states.len(), path_strs.len() + 1);
        let mut concat_str = String::new();
        for str in path_strs.into_iter() {
            let first_chars = str.as_bytes();
            concat_str += &(first_chars[0] as char).to_string();
        }
        let index_ends = part_regexes
            .iter()
            .map(|regex| {
                println!("regex {}", regex);
                println!("concat_str {}", concat_str);
                let found = regex.find(&concat_str).unwrap().unwrap();
                // println!("found {:?}", found);
                if found.start() == found.end() {
                    found.end() + 1
                } else {
                    found.end()
                }
            })
            .collect_vec();
        let mut substr_results = vec![];
        for index in public_config_indexes.iter() {
            let start = if *index == 0 {
                0
            } else {
                index_ends[index - 1]
            };
            let end = index_ends[*index];
            substr_results.push((
                path_states[(start)..=end].to_vec(),
                concat_str[0..=(end - 1)].to_string(),
            ));
        }
        Ok(substr_results)
    }
}

impl RegexAndDFA {
    pub fn from_regex_str_and_substr_defs(
        // max_byte_size: usize,
        regex_str: &str,
        substrs_defs_json: SubstrsDefsJson,
    ) -> Result<RegexAndDFA, CompilerError> {
        let dfa_val = regex_to_dfa(regex_str)?;
        let substr_defs_array = substrs_defs_json
            .transitions
            .into_iter()
            .map(|transitions_array| HashSet::<(usize, usize)>::from_iter(transitions_array))
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
    //     let substr_file_pathes = (0..num_public_parts)
    //         .map(|idx| halo2_dir_path.join(format!("substr_{}.txt", idx)))
    //         .collect_vec();
    //     regex_and_dfa
    //         .gen_halo2_tables(&allstr_file_path, &substr_file_pathes, gen_substrs)
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
    //     let substr_file_pathes = (0..num_public_parts)
    //         .map(|idx| halo2_dir_path.join(format!("substr_{}.txt", idx)))
    //         .collect_vec();
    //     regex_and_dfa
    //         .gen_halo2_tables(&allstr_file_path, &substr_file_pathes, gen_substrs)
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

pub(crate) fn get_accepted_state(dfa_val: &[Value]) -> Option<usize> {
    for i in 0..dfa_val.len() {
        if dfa_val[i]["type"] == "accept" {
            return Some(i as usize);
        }
    }
    None
}

pub(crate) fn get_max_state(dfa_val: &[Value]) -> Result<usize, JsCallerError> {
    let mut max_state = 0;
    for (_i, val) in dfa_val.iter().enumerate() {
        for (_, next_node_val) in val["edges"]
            .as_object()
            .ok_or(JsCallerError::InvalidEdges(val["edges"].clone()))?
            .iter()
        {
            let next_node = next_node_val
                .as_u64()
                .ok_or(JsCallerError::InvalidNodeValue(next_node_val.clone()))?
                as usize;
            if next_node > max_state {
                max_state = next_node;
            }
        }
    }
    Ok(max_state)
}

pub(crate) fn add_graph_nodes(
    dfa_val: &[Value],
    graph: &mut Graph<bool, char, Directed, usize>,
    last_max_state: Option<usize>,
    next_max_state: usize,
) -> Result<(), JsCallerError> {
    let first_new_state = match last_max_state {
        Some(v) => v + 1,
        None => 0,
    };
    for idx in first_new_state..=next_max_state {
        graph.add_node(idx == next_max_state);
    }

    for (i, val) in dfa_val.iter().enumerate() {
        for (key, next_node_val) in val["edges"]
            .as_object()
            .ok_or(JsCallerError::InvalidEdges(val["edges"].clone()))?
            .iter()
        {
            let next_node = next_node_val
                .as_u64()
                .ok_or(JsCallerError::InvalidNodeValue(next_node_val.clone()))?
                as usize;
            if let Some(max) = last_max_state {
                if i <= max && next_node <= max {
                    continue;
                }
            }
            let key_list: Vec<String> = serde_json::from_str::<Vec<String>>(&key)?
                .iter()
                .filter(|s| s.as_str() != "\u{ff}")
                .cloned()
                .collect_vec();
            // let mut key_str = String::new();
            // for key_char in key_list.iter() {
            //     // println!("key_char {}", key_char);
            //     assert!(key_char.len() == 1);
            //     // key_str += key_char;
            // }
            if key_list.len() == 0 {
                continue;
            }
            let mut key = None;
            for key_idx in 0..key_list.len() {
                let char = key_list[key_idx].chars().nth(0).unwrap();
                if (char as u8) < 10 || (char as u8) > 127 {
                    continue;
                }
                if key_list[key_idx].as_bytes().len() == 1 {
                    key = Some(char);
                    break;
                }
            }
            // assert_eq!(key_list[key_idx].as_bytes().len(), 1);
            graph.add_edge(
                NodeIndex::from(next_node),
                NodeIndex::from(i),
                key.expect("there is no representative character."),
            );
        }
    }
    Ok(())
}

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
    use std::path::Path;

    #[test]
    fn test_gen_from_decomposed() {
        let decomposed_regex_path = Path::new("../circuits/common/subject_all.json");
        let circom_file_path = Some("../circuits/common/subject_all_regex.circom");
        let circom_template_name = Some("SubjectAllRegex");
        let gen_substrs = Some(true);

        let result = gen_from_decomposed(
            decomposed_regex_path.to_str().unwrap(),
            circom_file_path.map(|s| s),
            circom_template_name.map(|s| s),
            gen_substrs,
        );

        // assert!(result.is_ok());
    }
}
