//! Builder pass to convert Thompson NFA to IntermediateNFA and then to final NFAGraph

use super::{NFAError, NFAResult};
use crate::ir::{IntermediateNFA, IntermediateNFANode, NFAGraph};

use regex_automata::{
    nfa::thompson::{NFA, State, Transition, pikevm::PikeVM},
    util::primitives::{SmallIndex, StateID},
};
use std::collections::{BTreeMap, BTreeSet};

impl NFAGraph {
    /// Build a final NFA from a regex pattern using a clean compilation pipeline
    ///
    /// Pipeline:
    /// 1. Create Thompson NFA using regex-automata
    /// 2. Convert to intermediate representation (with epsilon transitions)
    /// 3. Validate intermediate structure
    /// 4. Finalize to circuit-ready representation (no epsilon transitions)
    /// 5. Final validation
    pub fn build(pattern: &str) -> NFAResult<Self> {
        // Step 1: Create Thompson NFA
        let vm = PikeVM::new(pattern)
            .map_err(|e| NFAError::RegexCompilation(format!("Failed to create PikeVM: {}", e)))?;
        let thompson_nfa = vm.get_nfa();

        // Step 2: Convert to intermediate representation
        let intermediate = IntermediateNFA::from_thompson(pattern, &thompson_nfa)?;

        // Step 3: Validate intermediate structure
        intermediate.validate()?;

        // Step 4: Convert to final representation (removes epsilon transitions)
        let final_nfa = intermediate.finalize()?;

        Ok(final_nfa)
    }
}

impl IntermediateNFA {
    /// Create intermediate NFA from Thompson NFA with safe state handling
    pub fn from_thompson(pattern: &str, thompson: &NFA) -> NFAResult<Self> {
        let start_offset = thompson.start_anchored().as_usize();
        let total_states = thompson.states().len();

        if start_offset >= total_states {
            return Err(NFAError::InvalidStateId(
                "Invalid Thompson NFA: start offset exceeds total states".into(),
            ));
        }

        let logical_state_count = total_states - start_offset;

        let mut intermediate = Self::new(pattern.to_string());

        // Initialize nodes
        intermediate.nodes = (0..logical_state_count)
            .map(|id| IntermediateNFANode {
                state_id: id,
                byte_transitions: BTreeMap::new(),
                epsilon_transitions: BTreeSet::new(),
                capture_groups: BTreeMap::new(),
            })
            .collect();

        // Process all Thompson states
        for logical_id in 0..logical_state_count {
            let thompson_id = StateID::new(logical_id + start_offset)
                .map_err(|e| NFAError::InvalidStateId(format!("Invalid state ID: {}", e)))?;

            intermediate.process_thompson_state(
                &thompson,
                thompson_id,
                logical_id,
                start_offset,
            )?;
        }

        // Set start state (always 0 in our logical mapping)
        intermediate.start_states.insert(0);

        Ok(intermediate)
    }

    /// Process a single Thompson state and convert to intermediate representation
    fn process_thompson_state(
        &mut self,
        thompson: &NFA,
        thompson_id: StateID,
        logical_id: usize,
        start_offset: usize,
    ) -> NFAResult<()> {
        match thompson.state(thompson_id) {
            State::Match { .. } => {
                self.accept_states.insert(logical_id);
            }
            State::ByteRange { trans } => {
                self.add_byte_range_transition(logical_id, trans, start_offset)?;
            }
            State::Sparse(sparse) => {
                self.add_sparse_transitions(logical_id, &sparse.transitions, start_offset)?;
            }
            State::Dense(dense) => {
                self.add_dense_transitions(logical_id, &dense.transitions, start_offset)?;
            }
            State::Union { alternates } => {
                self.add_union_transitions(logical_id, alternates, start_offset)?;
            }
            State::BinaryUnion { alt1, alt2 } => {
                self.add_binary_union_transitions(logical_id, alt1, alt2, start_offset)?;
            }
            State::Capture {
                next,
                group_index,
                slot,
                ..
            } => {
                self.add_capture_transition(logical_id, next, group_index, slot, start_offset)?;
                self.num_capture_groups = self.num_capture_groups.max(group_index.as_usize());
            }
            State::Look { next, .. } => {
                self.add_look_transition(logical_id, next, start_offset)?;
            }
            State::Fail => {
                // No transitions needed for fail states
            }
        }
        Ok(())
    }

    // Helper methods for adding different types of transitions
    fn add_byte_range_transition(
        &mut self,
        state_id: usize,
        trans: &Transition,
        start_offset: usize,
    ) -> NFAResult<()> {
        let target = self.thompson_to_logical(trans.next.as_usize(), start_offset)?;

        for byte in trans.start..=trans.end {
            self.nodes[state_id]
                .byte_transitions
                .entry(byte)
                .or_insert_with(BTreeSet::new)
                .insert(target);
        }
        Ok(())
    }

    fn add_sparse_transitions(
        &mut self,
        state_id: usize,
        transitions: &[Transition],
        start_offset: usize,
    ) -> NFAResult<()> {
        for trans in transitions {
            self.add_byte_range_transition(state_id, trans, start_offset)?;
        }
        Ok(())
    }

    fn add_dense_transitions(
        &mut self,
        state_id: usize,
        transitions: &[StateID],
        start_offset: usize,
    ) -> NFAResult<()> {
        for (byte, &next_id) in transitions.iter().enumerate() {
            if next_id != StateID::ZERO {
                let target = self.thompson_to_logical(next_id.as_usize(), start_offset)?;
                self.nodes[state_id]
                    .byte_transitions
                    .entry(byte as u8)
                    .or_insert_with(BTreeSet::new)
                    .insert(target);
            }
        }
        Ok(())
    }

    fn add_union_transitions(
        &mut self,
        state_id: usize,
        alternates: &[StateID],
        start_offset: usize,
    ) -> NFAResult<()> {
        for &alt in alternates {
            let target = self.thompson_to_logical(alt.as_usize(), start_offset)?;
            self.nodes[state_id].epsilon_transitions.insert(target);
        }
        Ok(())
    }

    fn add_binary_union_transitions(
        &mut self,
        state_id: usize,
        alt1: &StateID,
        alt2: &StateID,
        start_offset: usize,
    ) -> NFAResult<()> {
        let target1 = self.thompson_to_logical(alt1.as_usize(), start_offset)?;
        let target2 = self.thompson_to_logical(alt2.as_usize(), start_offset)?;

        self.nodes[state_id].epsilon_transitions.insert(target1);
        self.nodes[state_id].epsilon_transitions.insert(target2);
        Ok(())
    }

    fn add_capture_transition(
        &mut self,
        state_id: usize,
        next: &StateID,
        group_index: &SmallIndex,
        slot: &SmallIndex,
        start_offset: usize,
    ) -> NFAResult<()> {
        let target = self.thompson_to_logical(next.as_usize(), start_offset)?;
        self.nodes[state_id].epsilon_transitions.insert(target);

        let group_id = group_index.as_usize();
        if group_id > 0 {
            let is_start = slot.as_usize() % 2 == 0;
            self.nodes[state_id]
                .capture_groups
                .entry(target)
                .or_insert_with(BTreeSet::new)
                .insert((group_id, is_start));
        }
        Ok(())
    }

    fn add_look_transition(
        &mut self,
        state_id: usize,
        next: &StateID,
        start_offset: usize,
    ) -> NFAResult<()> {
        let target = self.thompson_to_logical(next.as_usize(), start_offset)?;
        self.nodes[state_id].epsilon_transitions.insert(target);
        Ok(())
    }

    /// Convert Thompson state ID to logical state ID
    fn thompson_to_logical(&self, thompson_id: usize, start_offset: usize) -> NFAResult<usize> {
        if thompson_id < start_offset {
            return Err(NFAError::InvalidStateId(format!(
                "Thompson state {} is before start offset {}",
                thompson_id, start_offset
            )));
        }

        let logical_id = thompson_id - start_offset;
        if logical_id >= self.nodes.len() {
            return Err(NFAError::InvalidStateId(format!(
                "Logical state {} exceeds node count {}",
                logical_id,
                self.nodes.len()
            )));
        }

        Ok(logical_id)
    }
}
