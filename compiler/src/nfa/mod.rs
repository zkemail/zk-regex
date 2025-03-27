mod builder;
mod codegen;
mod debug;
mod epsilon;
mod error;
mod graph;

use std::collections::{HashMap, HashSet};

pub use error::NFAResult;

/// A node in the NFA graph
#[derive(Clone, Debug, Default)]
pub struct NFANode {
    /// Unique identifier for this state
    pub state_id: usize,

    /// Transitions on byte inputs: byte -> list of target states
    pub byte_transitions: HashMap<u8, Vec<usize>>,

    /// Epsilon transitions to other states
    pub epsilon_transitions: Vec<usize>,

    /// Capture group information: (group_index, is_start)
    pub capture_groups: Vec<(usize, bool)>,
}

/// Non-deterministic Finite Automaton representation
#[derive(Clone, Debug, Default)]
pub struct NFAGraph {
    /// All nodes/states in the NFA
    pub nodes: Vec<NFANode>,

    /// Set of start state indices
    pub start_states: HashSet<usize>,

    /// Set of accept state indices
    pub accept_states: HashSet<usize>,
}

impl NFAGraph {
    /// Create a new empty NFA
    pub fn new() -> Self {
        Self {
            nodes: Vec::new(),
            start_states: HashSet::new(),
            accept_states: HashSet::new(),
        }
    }
}
