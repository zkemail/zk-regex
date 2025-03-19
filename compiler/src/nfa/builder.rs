use regex_automata::{
    nfa::thompson::{State, pikevm::PikeVM},
    util::primitives::StateID,
};
use std::collections::{HashMap, HashSet};

use super::{NFAGraph, NFANode};
use crate::error::Error;

impl NFAGraph {
    /// Build an NFA from a regex pattern
    pub fn build(regex: &str) -> Result<Self, Error> {
        // Create the regex NFA using regex-automata
        let re = PikeVM::new(regex).map_err(|e| Error::BuildError(e.to_string()))?;
        let nfa = re.get_nfa();
        println!("NFA: {:?}", nfa);

        // Create a new NFAGraph
        let mut graph = NFAGraph {
            nodes: Vec::new(),
            start_states: HashSet::new(),
            accept_states: HashSet::new(),
        };

        // Create nodes for all states in the regex NFA
        for state_id in 0..nfa.states().len() {
            // Create a new node
            let node = NFANode {
                state_id,
                byte_transitions: HashMap::new(),
                epsilon_transitions: Vec::new(),
                capture_groups: Vec::new(),
            };

            // Add the node to the graph
            graph.nodes.push(node);
        }

        // Process each state to add transitions and capture group information
        for state_id in 0..nfa.states().len() {
            let state_id = StateID::new(state_id).map_err(|e| Error::BuildError(e.to_string()))?;
            let state = nfa.state(state_id);
            let state_id_usize = state_id.as_usize();

            // Handle different state types
            match state {
                State::Match { .. } => {
                    graph.accept_states.insert(state_id_usize);
                }
                State::ByteRange { trans } => {
                    // Add transition for every byte in range
                    for byte in trans.start..=trans.end {
                        graph.nodes[state_id_usize]
                            .byte_transitions
                            .entry(byte)
                            .or_insert_with(Vec::new)
                            .push(trans.next.as_usize());
                    }
                }
                State::Sparse(sparse_trans) => {
                    // Process each transition in sparse transitions
                    for trans in sparse_trans.transitions.iter() {
                        for byte in trans.start..=trans.end {
                            graph.nodes[state_id_usize]
                                .byte_transitions
                                .entry(byte)
                                .or_insert_with(Vec::new)
                                .push(trans.next.as_usize());
                        }
                    }
                }
                State::Dense(dense_trans) => {
                    // Process dense transitions (only non-zero ones)
                    for (byte, &next) in dense_trans.transitions.iter().enumerate() {
                        if next != StateID::ZERO {
                            graph.nodes[state_id_usize]
                                .byte_transitions
                                .entry(byte as u8)
                                .or_insert_with(Vec::new)
                                .push(next.as_usize());
                        }
                    }
                }
                State::Union { alternates } => {
                    // Add epsilon transitions for each alternate
                    graph.nodes[state_id_usize]
                        .epsilon_transitions
                        .extend(alternates.iter().map(|id| id.as_usize()));
                }
                State::BinaryUnion { alt1, alt2 } => {
                    // Add epsilon transitions for both alternates
                    graph.nodes[state_id_usize]
                        .epsilon_transitions
                        .push(alt1.as_usize());
                    graph.nodes[state_id_usize]
                        .epsilon_transitions
                        .push(alt2.as_usize());
                }
                State::Capture {
                    next,
                    group_index,
                    slot,
                    ..
                } => {
                    // Add epsilon transition for capture
                    graph.nodes[state_id_usize]
                        .epsilon_transitions
                        .push(next.as_usize());

                    // Add capture group information
                    let group_index = group_index.as_usize();
                    if group_index > 0 {
                        let is_start = slot.as_usize() % 2 == 0;
                        graph.nodes[state_id_usize]
                            .capture_groups
                            .push((group_index, is_start));
                    }
                }
                State::Look { next, .. } => {
                    // For simplicity, treat look-arounds as epsilon transitions
                    graph.nodes[state_id_usize]
                        .epsilon_transitions
                        .push(next.as_usize());
                }
                State::Fail => {
                    // No transitions from fail state
                }
            }
        }

        // Set the start states
        graph.start_states.insert(nfa.start_anchored().as_usize());
        graph.start_states.insert(nfa.start_unanchored().as_usize());

        graph.remove_epsilon_transitions();

        Ok(graph)
    }
}
