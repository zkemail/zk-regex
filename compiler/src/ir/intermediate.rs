//! Intermediate NFA representation during compilation
//!
//! This module contains the intermediate representation used during the compilation
//! pipeline. The intermediate NFA may contain epsilon transitions and other constructs
//! that need to be processed before generating the final circuit-ready representation.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

use super::nfa::{NFAGraph, NFANode};
use crate::passes::{NFAError, NFAResult};

/// Intermediate NFA node that may contain epsilon transitions
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct IntermediateNFANode {
    /// Unique identifier for this state
    pub state_id: usize,

    /// Byte-consuming transitions: byte -> set of target states
    pub byte_transitions: BTreeMap<u8, BTreeSet<usize>>,

    /// Epsilon (non-consuming) transitions to other states
    pub epsilon_transitions: BTreeSet<usize>,

    /// Capture group information: target_state -> capture_events
    pub capture_groups: BTreeMap<usize, BTreeSet<(usize, bool)>>,
}

/// Intermediate NFA representation used during compilation
///
/// This representation may contain epsilon transitions and other intermediate
/// constructs that need to be processed before circuit generation.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct IntermediateNFA {
    /// The original regex pattern
    pub regex: String,

    /// All states in the intermediate NFA
    pub nodes: Vec<IntermediateNFANode>,

    /// Set of start state indices
    pub start_states: BTreeSet<usize>,

    /// Set of accept state indices
    pub accept_states: BTreeSet<usize>,

    /// Number of capture groups in the regex
    pub num_capture_groups: usize,
}

impl IntermediateNFA {
    /// Create a new empty intermediate NFA
    pub fn new(regex: String) -> Self {
        Self {
            regex,
            nodes: Vec::new(),
            start_states: BTreeSet::new(),
            accept_states: BTreeSet::new(),
            num_capture_groups: 0,
        }
    }

    /// Validate the structural integrity of the intermediate NFA
    pub fn validate(&self) -> NFAResult<()> {
        if self.nodes.is_empty() {
            return Err(NFAError::EmptyAutomaton(
                "No states in intermediate NFA".into(),
            ));
        }

        if self.start_states.is_empty() {
            return Err(NFAError::Verification("No start states defined".into()));
        }

        // Validate state IDs are sequential and match indices
        for (idx, node) in self.nodes.iter().enumerate() {
            if node.state_id != idx {
                return Err(NFAError::InvalidStateId(format!(
                    "State ID {} doesn't match index {} in intermediate NFA",
                    node.state_id, idx
                )));
            }
        }

        // Validate transition targets are within bounds
        for (state_idx, node) in self.nodes.iter().enumerate() {
            // Check byte transitions
            for destinations in node.byte_transitions.values() {
                for &dest in destinations {
                    if dest >= self.nodes.len() {
                        return Err(NFAError::InvalidTransition(format!(
                            "Byte transition from state {} to invalid state {}",
                            state_idx, dest
                        )));
                    }
                }
            }

            // Check epsilon transitions
            for &dest in &node.epsilon_transitions {
                if dest >= self.nodes.len() {
                    return Err(NFAError::InvalidTransition(format!(
                        "Epsilon transition from state {} to invalid state {}",
                        state_idx, dest
                    )));
                }
            }
        }

        Ok(())
    }

    /// Convert the intermediate NFA to a final circuit-ready NFA
    ///
    /// This process eliminates epsilon transitions and creates a clean
    /// final representation suitable for circuit generation.
    pub fn finalize(self) -> NFAResult<NFAGraph> {
        // Create a mutable copy for epsilon elimination
        let mut intermediate = self;

        // Remove epsilon transitions using the existing algorithm
        intermediate.remove_epsilon_transitions()?;

        // Convert to final representation (no epsilon transitions)
        let final_nodes: Vec<NFANode> = intermediate
            .nodes
            .into_iter()
            .map(|intermediate_node| NFANode {
                state_id: intermediate_node.state_id,
                byte_transitions: intermediate_node.byte_transitions,
                capture_groups: intermediate_node.capture_groups,
            })
            .collect();

        let final_nfa = NFAGraph {
            regex: intermediate.regex,
            nodes: final_nodes,
            start_states: intermediate.start_states,
            accept_states: intermediate.accept_states,
            num_capture_groups: intermediate.num_capture_groups,
        };

        // Final validation
        final_nfa.verify()?;

        Ok(final_nfa)
    }
}

// Implement epsilon transition removal for intermediate NFA
impl IntermediateNFA {
    /// Remove epsilon transitions while preserving language semantics
    fn remove_epsilon_transitions(&mut self) -> NFAResult<()> {
        // Compute epsilon closures for all states
        let closures = self.compute_epsilon_closures()?;

        let mut new_transitions = vec![BTreeMap::new(); self.nodes.len()];
        let mut new_captures = vec![BTreeMap::new(); self.nodes.len()];
        let mut new_start_states = BTreeSet::new();
        let mut new_accept_states = BTreeSet::new();

        // Track states with byte transitions
        let mut has_byte_transitions = vec![false; self.nodes.len()];

        // Process epsilon closures and create new transitions
        for (state, closure) in closures.iter().enumerate() {
            // Mark state as accepting if any state in closure is accepting
            if closure.is_accept {
                new_accept_states.insert(state);
            }

            // For each state reachable via epsilon that has byte transitions
            for &r_state in &closure.states {
                if !self.nodes[r_state].byte_transitions.is_empty() {
                    has_byte_transitions[r_state] = true;

                    // Create direct byte transitions bypassing epsilon transitions
                    for (&byte, targets) in &self.nodes[r_state].byte_transitions {
                        for &actual_target in targets {
                            new_transitions[state]
                                .entry(byte)
                                .or_insert_with(BTreeSet::new)
                                .insert(actual_target);

                            // Merge capture group information
                            let captures_for_transition = new_captures[state]
                                .entry(actual_target)
                                .or_insert_with(BTreeSet::new);

                            // Add start captures from epsilon path before byte transition
                            for &(_, (group_id, is_start)) in &closure.captures {
                                if is_start {
                                    captures_for_transition.insert((group_id, true));
                                }
                            }

                            // Add end captures from epsilon path after byte transition
                            let target_closure = &closures[actual_target];
                            for &(_, (group_id, is_start)) in &target_closure.captures {
                                if !is_start {
                                    captures_for_transition.insert((group_id, false));
                                }
                            }
                        }
                    }
                }
            }
        }

        // Handle start states carefully to preserve capture semantics
        let original_starts: BTreeSet<usize> = self.start_states.iter().copied().collect();

        for &orig_start in &original_starts {
            new_start_states.insert(orig_start);

            // Check if start state's closure has start captures
            let has_start_captures = closures
                .get(orig_start)
                .map(|closure| closure.captures.iter().any(|(_, (_, is_start))| *is_start))
                .unwrap_or(false);

            // Only add alternative start states if no start captures would be bypassed
            if !has_start_captures {
                if let Some(closure) = closures.get(orig_start) {
                    for &r_state in &closure.states {
                        if r_state != orig_start
                            && r_state < has_byte_transitions.len()
                            && has_byte_transitions[r_state]
                        {
                            new_start_states.insert(r_state);
                        }
                    }
                }
            }
        }

        // Apply the changes
        self.start_states = new_start_states;
        self.accept_states = new_accept_states;

        for (state, (transitions, captures)) in new_transitions
            .into_iter()
            .zip(new_captures.into_iter())
            .enumerate()
        {
            self.nodes[state].byte_transitions = transitions;
            self.nodes[state].capture_groups = captures;
            self.nodes[state].epsilon_transitions.clear(); // Remove all epsilon transitions
        }

        // Clean up unreachable states
        self.remove_unreachable_states();

        Ok(())
    }

    /// Compute epsilon closures using the existing algorithm
    fn compute_epsilon_closures(&self) -> NFAResult<Vec<EpsilonClosure>> {
        let mut closures = Vec::new();
        for state in 0..self.nodes.len() {
            closures.push(self.compute_epsilon_closure(state)?);
        }
        Ok(closures)
    }

    fn compute_epsilon_closure(&self, start: usize) -> NFAResult<EpsilonClosure> {
        let mut closure = EpsilonClosure {
            states: BTreeSet::new(),
            captures: BTreeSet::new(),
            is_accept: false,
        };

        fn dfs(
            nfa: &IntermediateNFA,
            state: usize,
            closure: &mut EpsilonClosure,
            visited: &mut BTreeSet<usize>,
        ) -> NFAResult<()> {
            if !visited.insert(state) {
                return Ok(());
            }

            closure.states.insert(state);

            // Collect capture information
            for (&capture_state, captures) in &nfa.nodes[state].capture_groups {
                for capture in captures {
                    closure.captures.insert((capture_state, *capture));
                }
            }

            // Check if this state is accepting
            if nfa.accept_states.contains(&state) {
                closure.is_accept = true;
            }

            // Follow epsilon transitions
            for &next in &nfa.nodes[state].epsilon_transitions {
                dfs(nfa, next, closure, visited)?;
            }

            Ok(())
        }

        let mut visited = BTreeSet::new();
        dfs(self, start, &mut closure, &mut visited)?;

        Ok(closure)
    }

    fn remove_unreachable_states(&mut self) {
        // Find reachable states via BFS
        let mut reachable = BTreeSet::new();
        let mut queue = Vec::new();

        // Start from all start states
        for &start in &self.start_states {
            if reachable.insert(start) {
                queue.push(start);
            }
        }

        // BFS to find all reachable states
        while let Some(state) = queue.pop() {
            if state < self.nodes.len() {
                for targets in self.nodes[state].byte_transitions.values() {
                    for &target in targets {
                        if reachable.insert(target) {
                            queue.push(target);
                        }
                    }
                }
            }
        }

        // Remove unreachable states if any exist
        if reachable.len() < self.nodes.len() {
            self.compact_states(reachable);
        }
    }

    fn compact_states(&mut self, reachable: BTreeSet<usize>) {
        // Create mapping from old to new indices
        let mut old_to_new = BTreeMap::new();
        let mut new_nodes = Vec::with_capacity(reachable.len());

        let mut new_idx = 0;
        for &old_idx in &reachable {
            old_to_new.insert(old_idx, new_idx);
            new_idx += 1;
        }

        // Create compacted nodes with updated indices
        for &old_idx in &reachable {
            let mut node = self.nodes[old_idx].clone();
            node.state_id = old_to_new[&old_idx];

            // Update byte transition targets
            let mut new_byte_transitions = BTreeMap::new();
            for (byte, targets) in node.byte_transitions {
                let new_targets: BTreeSet<usize> = targets
                    .into_iter()
                    .filter_map(|target| old_to_new.get(&target).copied())
                    .collect();

                if !new_targets.is_empty() {
                    new_byte_transitions.insert(byte, new_targets);
                }
            }
            node.byte_transitions = new_byte_transitions;

            // Update capture group targets
            let mut new_captures = BTreeMap::new();
            for (target, captures) in node.capture_groups {
                if let Some(&new_target) = old_to_new.get(&target) {
                    new_captures.insert(new_target, captures);
                }
            }
            node.capture_groups = new_captures;

            new_nodes.push(node);
        }

        // Update start and accept states
        self.start_states = self
            .start_states
            .iter()
            .filter_map(|&state| old_to_new.get(&state).copied())
            .collect();

        self.accept_states = self
            .accept_states
            .iter()
            .filter_map(|&state| old_to_new.get(&state).copied())
            .collect();

        self.nodes = new_nodes;
    }
}

/// Epsilon closure computation helper
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct EpsilonClosure {
    states: BTreeSet<usize>,
    captures: BTreeSet<(usize, (usize, bool))>,
    is_accept: bool,
}
