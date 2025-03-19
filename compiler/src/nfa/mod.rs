mod builder;
mod codegen;
mod debug;
mod graph;

use std::collections::{HashMap, HashSet};

/// A node in the NFA graph
#[derive(Debug, Clone)]
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
#[derive(Debug, Clone)]
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
        let nfa = NFAGraph::build("Dkim(Signatu)re").unwrap();
        println!("NFA: {:?}", nfa);
        let nfa_without_epsilon = nfa.remove_epsilon_transitions();
        println!("\nNFA without epsilon transitions:");
        nfa_without_epsilon.print_concise();

        let stats = nfa_without_epsilon.get_stats();
        println!("NFA stats: {:?}", stats);

        nfa_without_epsilon.print_transitions_for_circom();
        let circom_code = nfa_without_epsilon
            .generate_circom_code("Rando", "a*b", Some(&[5]))
            .unwrap();
        // println!("Circom code:\n{}", circom_code);

        // Create the output directory directly
        std::fs::create_dir_all("output").unwrap();

        // Write the code to the file
        let mut file = File::create("output/Rando.circom").unwrap();
        file.write_all(circom_code.as_bytes()).unwrap();
    }
}
