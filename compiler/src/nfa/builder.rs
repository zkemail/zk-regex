use super::{NFAGraph, NFANode, NFAResult, error::NFAError};

use regex_automata::{
    nfa::thompson::{NFA, State, Transition, pikevm::PikeVM},
    util::primitives::{SmallIndex, StateID},
};
use std::collections::{BTreeMap, BTreeSet};

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
        let re = PikeVM::new(pattern).map_err(|e| NFAError::RegexCompilation(e.to_string()))?;
        let thompson_nfa = re.get_nfa();

        let state_len = thompson_nfa.states().len() - 2;

        let mut graph = Self::default();
        graph.regex = pattern.to_string();
        graph.initialize_nodes(state_len)?;
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
                byte_transitions: BTreeMap::new(),
                epsilon_transitions: BTreeSet::new(),
                capture_groups: BTreeMap::new(),
            })
            .collect();

        Ok(())
    }

    /// Processes all states from the Thompson NFA
    fn process_all_states(&mut self, nfa: &NFA) -> NFAResult<()> {
        for state_idx in 0..self.nodes.len() {
            let state_id =
                StateID::new(state_idx + 2).map_err(|e| NFAError::InvalidStateId(e.to_string()))?;

            match nfa.state(state_id) {
                State::Match { .. } => {
                    self.accept_states.insert(state_idx);
                }
                State::ByteRange { trans } => {
                    self.add_byte_range_transition(state_idx, trans)?;
                }
                State::Sparse(sparse) => {
                    self.add_sparse_transitions(state_idx, &sparse.transitions)?;
                }
                State::Dense(dense) => {
                    self.add_dense_transitions(state_idx, &dense.transitions)?;
                }
                State::Union { alternates } => {
                    self.add_union_transitions(state_idx, alternates)?;
                }
                State::BinaryUnion { alt1, alt2 } => {
                    self.add_binary_union_transitions(state_idx, alt1, alt2)?;
                }
                State::Capture {
                    next,
                    group_index,
                    slot,
                    ..
                } => {
                    self.add_capture_transition(state_idx, next, group_index, slot)?;
                }
                State::Look { next, .. } => {
                    self.add_look_transition(state_idx, next)?;
                }
                State::Fail => {} // No transitions needed
            }
        }
        Ok(())
    }

    /// Adds a byte range transition to the graph
    fn add_byte_range_transition(&mut self, state_id: usize, trans: &Transition) -> NFAResult<()> {
        for byte in trans.start..=trans.end {
            self.nodes[state_id]
                .byte_transitions
                .entry(byte)
                .or_insert_with(BTreeSet::new)
                .insert(trans.next.as_usize() - 2);
        }
        Ok(())
    }

    /// Adds transitions from a sparse transition set
    fn add_sparse_transitions(
        &mut self,
        state_id: usize,
        transitions: &[Transition],
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
                self.nodes[state_id]
                    .byte_transitions
                    .entry(byte as u8)
                    .or_insert_with(BTreeSet::new)
                    .insert(next.as_usize() - 2);
            }
        }
        Ok(())
    }

    /// Adds epsilon transitions for a union state
    fn add_union_transitions(&mut self, state_id: usize, alternates: &[StateID]) -> NFAResult<()> {
        self.nodes[state_id]
            .epsilon_transitions
            .extend(alternates.iter().map(|id| id.as_usize() - 2));
        Ok(())
    }

    /// Adds epsilon transitions for a binary union state
    fn add_binary_union_transitions(
        &mut self,
        state_id: usize,
        alt1: &StateID,
        alt2: &StateID,
    ) -> NFAResult<()> {
        let node = &mut self.nodes[state_id];
        node.epsilon_transitions.insert(alt1.as_usize() - 2);
        node.epsilon_transitions.insert(alt2.as_usize() - 2);
        Ok(())
    }

    /// Adds an epsilon transition with capture group information
    fn add_capture_transition(
        &mut self,
        state_id: usize,
        next: &StateID,
        group_index: &SmallIndex,
        slot: &SmallIndex,
    ) -> NFAResult<()> {
        let node = &mut self.nodes[state_id];
        node.epsilon_transitions.insert(next.as_usize() - 2);

        let group_idx = group_index.as_usize();
        if group_idx > 0 {
            let is_start = slot.as_usize() % 2 == 0;
            node.capture_groups
                .entry(next.as_usize() - 2)
                .or_insert_with(BTreeSet::new)
                .insert((group_idx, is_start));
        }
        Ok(())
    }

    /// Adds an epsilon transition for a look-around state
    fn add_look_transition(&mut self, state_id: usize, next: &StateID) -> NFAResult<()> {
        self.nodes[state_id]
            .epsilon_transitions
            .insert(next.as_usize() - 2);
        Ok(())
    }

    /// Sets the start states for the NFA
    fn set_start_states(&mut self, nfa: &NFA) {
        self.start_states
            .insert(nfa.start_anchored().as_usize() - 2);
    }

    pub fn pretty_print(&self) {
        println!("\n=== NFA Graph ===");
        println!("Regex: {}", self.regex);
        println!("Start states: {:?}", self.start_states);
        println!("Accept states: {:?}", self.accept_states);
        println!("\nStates:");

        for (idx, node) in self.nodes.iter().enumerate() {
            println!("\nState {}: ", idx);

            // Print byte transitions
            if !node.byte_transitions.is_empty() {
                println!("  Byte transitions:");
                for (&byte, destinations) in &node.byte_transitions {
                    println!(
                        "    '{}' ({:#04x}) -> {:?}",
                        if byte.is_ascii_graphic() {
                            byte as char
                        } else {
                            '.'
                        },
                        byte,
                        destinations
                    );
                }
            }

            // Print capture groups
            if !node.capture_groups.is_empty() {
                println!("  Capture groups:");
                for (target, captures) in &node.capture_groups {
                    for &(group_id, is_start) in captures {
                        println!(
                            "    -> state {}: group {} {}",
                            target,
                            group_id,
                            if is_start { "start" } else { "end" }
                        );
                    }
                }
            }
        }
        println!("\n=== End of Graph ===\n");
    }
}
