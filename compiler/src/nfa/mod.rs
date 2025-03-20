mod builder;
mod cache;
mod codegen;
mod debug;
mod graph;

use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

/// A node in the NFA graph
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NFANode {
    /// Original state ID for debugging/reference
    pub state_id: usize,
    /// Byte transitions to other states (byte -> indices into nodes vec)
    pub byte_transitions: HashMap<u8, Vec<usize>>,
    /// Epsilon transitions to other states (indices into nodes vec)
    pub epsilon_transitions: Vec<usize>,
    /// Capture group information (group_id, is_start)
    pub capture_groups: Vec<(usize, bool)>,
}

/// An NFA graph using an arena-based approach
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NFAGraph {
    /// All nodes in the graph
    pub nodes: Vec<NFANode>,
    /// Indices of start states
    pub start_states: HashSet<usize>,
    /// Indices of accept states
    pub accept_states: HashSet<usize>,
}

#[cfg(test)]
mod tests {
    use std::{fs::File, io::Write};

    use super::*;

    #[test]
    fn test_build() {
        let nfa =
            NFAGraph::build("(?:\r\n|^)dkim-signature:(?:[a-z]+=[^;]+; )+t=([0-9]+);").unwrap();

        nfa.save_to_file("nfa.json").unwrap();
        let nfa_deserialized = NFAGraph::load_from_file("nfa.json").unwrap();
        assert_eq!(nfa, nfa_deserialized);

        let noir_code = nfa.generate_noir_code(
            "(?:\\r\\n|^)dkim-signature:(?:[a-z]+=[^;]+; )+t=([0-9]+);",
            None
        ).unwrap();

        // Write the code to the file
        let mut file = File::create("output/noir/src/main.nr").unwrap();
        file.write_all(noir_code.as_bytes()).unwrap();
    }
}
