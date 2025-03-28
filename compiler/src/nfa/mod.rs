mod builder;
mod codegen;
mod epsilon;
mod error;
mod graph;

use std::collections::{BTreeMap, BTreeSet};

pub use error::NFAResult;

/// A node in the NFA graph
#[derive(Clone, Debug, Default)]
pub struct NFANode {
    /// Unique identifier for this state
    pub state_id: usize,

    /// Transitions on byte inputs: byte -> list of target states
    pub byte_transitions: BTreeMap<u8, BTreeSet<usize>>,

    /// Epsilon transitions to other states
    pub epsilon_transitions: BTreeSet<usize>,

    /// Capture group information: target state -> set of captures
    pub capture_groups: BTreeMap<usize, BTreeSet<(usize, bool)>>,
}

/// Non-deterministic Finite Automaton representation
#[derive(Clone, Debug, Default)]
pub struct NFAGraph {
    /// All nodes/states in the NFA
    pub nodes: Vec<NFANode>,

    /// Set of start state indices
    pub start_states: BTreeSet<usize>,

    /// Set of accept state indices
    pub accept_states: BTreeSet<usize>,
}

impl NFAGraph {
    /// Create a new empty NFA
    pub fn new() -> Self {
        Self {
            nodes: Vec::new(),
            start_states: BTreeSet::new(),
            accept_states: BTreeSet::new(),
        }
    }
}
