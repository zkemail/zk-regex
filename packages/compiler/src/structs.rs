use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet, VecDeque};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegexPartConfig {
    pub is_public: bool,
    pub regex_def: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecomposedRegexConfig {
    pub parts: VecDeque<RegexPartConfig>,
}

#[derive(Debug, Clone)]
pub struct DFAStateInfo {
    pub typ: String,
    pub source: usize,
    pub edges: BTreeMap<String, usize>,
}

#[derive(Debug)]
pub struct DFAGraphInfo {
    pub states: Vec<DFAStateInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DFAStateNode {
    pub state_type: String,
    pub state_id: usize,
    pub transitions: BTreeMap<usize, BTreeSet<u8>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DFAGraph {
    pub states: Vec<DFAStateNode>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstringDefinitions {
    pub substring_ranges: Vec<BTreeSet<(usize, usize)>>,
    pub substring_boundaries: Option<Vec<(BTreeSet<usize>, BTreeSet<usize>)>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegexAndDFA {
    pub regex_pattern: String,
    pub dfa: DFAGraph,
    pub has_end_anchor: bool,
    pub substrings: SubstringDefinitions,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstringDefinitionsJson {
    pub transitions: Vec<Vec<(usize, usize)>>,
}
