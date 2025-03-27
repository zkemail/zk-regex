use super::{ NFAGraph, NFANode, NFAResult, error::NFABuildError };

use regex_automata::{
    nfa::thompson::{ NFA, State, Transition, pikevm::PikeVM },
    util::primitives::{ SmallIndex, StateID },
};
use std::collections::HashMap;

impl NFAGraph {
    /// Builds an NFA from a regex pattern using Thompson construction.
    ///
    /// This implementation:
    /// 1. Creates a Thompson NFA using regex-automata
    /// 2. Converts it to our graph representation
    /// 3. Processes all states and their transitions
    /// 4. Handles capture groups and lookups
    /// 5. Removes epsilon transitions for circuit compatibility
    pub fn build(pattern: &str) -> NFAResult<Self> {
        let re = PikeVM::new(pattern).map_err(|e| NFABuildError::Build(e.to_string()))?;
        let thompson_nfa = re.get_nfa();

        let mut graph = Self::default();
        graph.initialize_nodes(thompson_nfa.states().len())?;
        graph.process_all_states(&thompson_nfa)?;
        graph.set_start_states(&thompson_nfa);
        graph.remove_epsilon_transitions()?;

        graph.verify()?;

        Ok(graph)
    }

    /// Initializes the graph with empty nodes
    fn initialize_nodes(&mut self, state_count: usize) -> NFAResult<()> {
        self.nodes = (0..state_count)
            .map(|id| NFANode {
                state_id: id,
                byte_transitions: HashMap::new(),
                epsilon_transitions: Vec::new(),
                capture_groups: Vec::new(),
            })
            .collect();

        Ok(())
    }

    /// Processes all states from the Thompson NFA
    fn process_all_states(&mut self, nfa: &NFA) -> NFAResult<()> {
        for state_id in 0..nfa.states().len() {
            let state_id = StateID::new(state_id).map_err(|e| NFABuildError::Build(e.to_string()))?;

            match nfa.state(state_id) {
                State::Match { .. } => {
                    self.accept_states.insert(state_id.as_usize());
                }
                State::ByteRange { trans } => {
                    self.add_byte_range_transition(state_id.as_usize(), trans)?;
                }
                State::Sparse(sparse) => {
                    self.add_sparse_transitions(state_id.as_usize(), &sparse.transitions)?;
                }
                State::Dense(dense) => {
                    self.add_dense_transitions(state_id.as_usize(), &dense.transitions)?;
                }
                State::Union { alternates } => {
                    self.add_union_transitions(state_id.as_usize(), alternates)?;
                }
                State::BinaryUnion { alt1, alt2 } => {
                    self.add_binary_union_transitions(state_id.as_usize(), alt1, alt2)?;
                }
                State::Capture { next, group_index, slot, .. } => {
                    self.add_capture_transition(state_id.as_usize(), next, group_index, slot)?;
                }
                State::Look { next, .. } => {
                    self.add_look_transition(state_id.as_usize(), next)?;
                }
                State::Fail => {} // No transitions needed
            }
        }
        Ok(())
    }

    /// Adds a byte range transition to the graph
    fn add_byte_range_transition(&mut self, state_id: usize, trans: &Transition) -> NFAResult<()> {
        for byte in trans.start..=trans.end {
            self.nodes[state_id].byte_transitions
                .entry(byte)
                .or_insert_with(Vec::new)
                .push(trans.next.as_usize());
        }
        Ok(())
    }

    /// Adds transitions from a sparse transition set
    fn add_sparse_transitions(
        &mut self,
        state_id: usize,
        transitions: &[Transition]
    ) -> NFAResult<()> {
        for trans in transitions {
            self.add_byte_range_transition(state_id, trans)?;
        }
        Ok(())
    }

    /// Adds transitions from a dense transition table
    fn add_dense_transitions(&mut self, state_id: usize, transitions: &[StateID]) -> NFAResult<()> {
        for (byte, &next) in transitions.iter().enumerate() {
            if next != StateID::ZERO {
                self.nodes[state_id].byte_transitions
                    .entry(byte as u8)
                    .or_insert_with(Vec::new)
                    .push(next.as_usize());
            }
        }
        Ok(())
    }

    /// Adds epsilon transitions for a union state
    fn add_union_transitions(&mut self, state_id: usize, alternates: &[StateID]) -> NFAResult<()> {
        self.nodes[state_id].epsilon_transitions.extend(alternates.iter().map(|id| id.as_usize()));
        Ok(())
    }

    /// Adds epsilon transitions for a binary union state
    fn add_binary_union_transitions(
        &mut self,
        state_id: usize,
        alt1: &StateID,
        alt2: &StateID
    ) -> NFAResult<()> {
        let node = &mut self.nodes[state_id];
        node.epsilon_transitions.push(alt1.as_usize());
        node.epsilon_transitions.push(alt2.as_usize());
        Ok(())
    }

    /// Adds an epsilon transition with capture group information
    fn add_capture_transition(
        &mut self,
        state_id: usize,
        next: &StateID,
        group_index: &SmallIndex,
        slot: &SmallIndex
    ) -> NFAResult<()> {
        let node = &mut self.nodes[state_id];
        node.epsilon_transitions.push(next.as_usize());

        let group_idx = group_index.as_usize();
        if group_idx > 0 {
            let is_start = slot.as_usize() % 2 == 0;
            node.capture_groups.push((group_idx, is_start));
        }
        Ok(())
    }

    /// Adds an epsilon transition for a look-around state
    fn add_look_transition(&mut self, state_id: usize, next: &StateID) -> NFAResult<()> {
        self.nodes[state_id].epsilon_transitions.push(next.as_usize());
        Ok(())
    }

    /// Sets the start states for the NFA
    fn set_start_states(&mut self, nfa: &NFA) {
        self.start_states.insert(nfa.start_anchored().as_usize());
        self.start_states.insert(nfa.start_unanchored().as_usize());
    }
}
