//! Epsilon transition removal pass

use super::NFAResult;
use crate::ir::NFAGraph;
use std::collections::{BTreeMap, BTreeSet};

/// Represents a closure of states reachable through epsilon transitions.
/// This includes all states that can be reached without consuming any input,
/// along with their associated capture groups and accept state status.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct EpsilonClosure {
    /// States reachable through epsilon transitions (including the start state)
    states: BTreeSet<usize>,
    /// Captures encountered along epsilon paths: (state_id, (group_id, is_start))
    /// The state_id indicates where the capture was originally located
    captures: BTreeSet<(usize, (usize, bool))>,
    /// Whether any state in this closure is an accept state
    is_accept: bool,
}

impl NFAGraph {
    /// Removes epsilon transitions from the NFA while preserving its behavior.
    ///
    /// This process:
    /// 1. Computes epsilon closures for all states
    /// 2. Creates direct byte transitions that bypass epsilon transitions
    /// 3. Updates capture groups to maintain correct capture semantics
    /// 4. Preserves start and accept state properties
    ///
    /// For example, if we have:
    ///   S --ε--> R1(c1) --byte--> T
    /// It becomes:
    ///   S --byte--> T(c1)
    ///
    /// The capture groups move to the target states of byte transitions
    /// to maintain correct capture behavior after epsilon removal.
    pub fn remove_epsilon_transitions(&mut self) -> NFAResult<()> {
        // Compute epsilon closures for all states
        let closures = self.compute_epsilon_closures()?;

        let mut new_transitions = vec![BTreeMap::new(); self.nodes.len()];
        let mut new_captures = vec![BTreeMap::new(); self.nodes.len()];
        let mut new_start_states = BTreeSet::new();
        let mut new_accept_states = BTreeSet::new();

        // Track states with byte transitions (to determine which states to keep)
        let mut has_byte_transitions = vec![false; self.nodes.len()];

        // First pass: process epsilon closures and set up new transitions
        for (state, closure) in closures.iter().enumerate() {
            // If any state in the closure is an accept state, this state becomes accept
            if closure.is_accept {
                new_accept_states.insert(state);
            }

            // For each reachable state via epsilon that has byte transitions
            for &r_state in &closure.states {
                if !self.nodes[r_state].byte_transitions.is_empty() {
                    has_byte_transitions[r_state] = true;

                    // Add byte transitions from r_state to the source state `state`
                    for (&byte, targets) in &self.nodes[r_state].byte_transitions {
                        for &actual_target in targets {
                            new_transitions[state]
                                .entry(byte)
                                .or_insert_with(BTreeSet::new)
                                .insert(actual_target);

                            // Collect all captures for the new transition: state --byte--> actual_target
                            let captures_for_this_transition = new_captures[state]
                                .entry(actual_target)
                                .or_insert_with(BTreeSet::new);

                            // 1. Add START events from the epsilon path leading from `state` up to `r_state`
                            //    (before the byte transition at `r_state`).
                            //    `closure` is `closures[state]`.
                            for &(_original_epsilon_source_state, (group_id, is_start_event)) in
                                &closure.captures
                            {
                                if is_start_event {
                                    // This is a START event for group_id
                                    captures_for_this_transition.insert((group_id, true));
                                }
                            }

                            // 2. Add END events from the epsilon path starting FROM `actual_target`
                            //    (after `byte` is consumed and actual_target is reached).
                            //    `closure_of_actual_target` is `closures[actual_target]`.
                            let closure_of_actual_target = &closures[actual_target];
                            for &(_orig_eps_src_from_target_closure, (group_id, is_start_event)) in
                                &closure_of_actual_target.captures
                            {
                                if !is_start_event {
                                    // This is an END event for group_id
                                    captures_for_this_transition.insert((group_id, false));
                                }
                            }
                        }
                    }
                }
            }
        }

        // Handle start states
        // Preserve original start states to iterate over them
        let original_start_states_snapshot: BTreeSet<usize> =
            self.start_states.iter().copied().collect();
        new_start_states.clear();

        for &orig_start in &original_start_states_snapshot {
            new_start_states.insert(orig_start); // The original start state is always kept

            // Check if the closure of this original start state contains any START captures.
            // If so, we don't want to create alternative start points from within this closure,
            // as that might allow bypassing these essential start captures.
            let mut has_start_captures_in_orig_closure = false;
            if let Some(orig_closure) = closures.get(orig_start) {
                for &(_, (_group_id, is_start_event)) in &orig_closure.captures {
                    if is_start_event {
                        has_start_captures_in_orig_closure = true;
                        break;
                    }
                }
            }

            if !has_start_captures_in_orig_closure {
                // If no start captures in orig_start's closure, it's safe to add
                // other states from its closure that have byte transitions as new start states.
                if let Some(orig_closure) = closures.get(orig_start) {
                    for &r_state in &orig_closure.states {
                        if r_state == orig_start {
                            continue;
                        }
                        // Check if r_state (a state reachable via epsilon from orig_start)
                        // itself is the source of a byte transition.
                        // The has_byte_transitions vec was populated based on nodes[r_state].byte_transitions
                        if r_state < has_byte_transitions.len() && has_byte_transitions[r_state] {
                            new_start_states.insert(r_state);
                        }
                    }
                }
            }
            // If has_start_captures_in_orig_closure is true, we *only* keep orig_start.
            // This forces paths through orig_start, ensuring its transitions (which will
            // have correctly accumulated these start captures) are used.
        }

        // Apply changes
        self.start_states = new_start_states;
        self.accept_states = new_accept_states;
        for (state, (transitions, captures)) in new_transitions
            .into_iter()
            .zip(new_captures.into_iter())
            .enumerate()
        {
            self.nodes[state].byte_transitions = transitions;
            self.nodes[state].capture_groups = captures;
            self.nodes[state].epsilon_transitions.clear();
        }

        // Remove unreachable states
        self.remove_unreachable_states();

        Ok(())
    }

    /// Computes epsilon closures for all states in the NFA.
    /// An epsilon closure for a state includes all states reachable
    /// through zero or more epsilon transitions.
    fn compute_epsilon_closures(&self) -> NFAResult<Vec<EpsilonClosure>> {
        let mut closures = Vec::new();
        for state in 0..self.nodes.len() {
            closures.push(self.compute_epsilon_closure(state)?);
        }
        Ok(closures)
    }

    /// Computes the epsilon closure for a single state using depth-first search.
    ///
    /// The closure includes:
    /// - All states reachable through epsilon transitions
    /// - Capture groups encountered along epsilon paths
    /// - Accept state status (true if any reachable state is accepting)
    ///
    /// DFS ensures we find all reachable states and handles cycles in
    /// epsilon transitions correctly.
    fn compute_epsilon_closure(&self, start: usize) -> NFAResult<EpsilonClosure> {
        let mut closure = EpsilonClosure {
            states: BTreeSet::new(),
            captures: BTreeSet::new(),
            is_accept: false,
        };

        fn dfs(
            graph: &NFAGraph,
            state: usize,
            closure: &mut EpsilonClosure,
            visited: &mut BTreeSet<usize>,
        ) -> NFAResult<()> {
            if !visited.insert(state) {
                return Ok(());
            }

            closure.states.insert(state);

            for (&capture_state, captures) in &graph.nodes[state].capture_groups {
                for capture in captures {
                    closure.captures.insert((capture_state, *capture));
                }
            }

            if graph.accept_states.contains(&state) {
                closure.is_accept = true;
            }

            for &next in &graph.nodes[state].epsilon_transitions {
                dfs(graph, next, closure, visited)?;
            }

            Ok(())
        }

        let mut visited = BTreeSet::new();
        dfs(self, start, &mut closure, &mut visited)?;

        Ok(closure)
    }

    // New helper method to remove unreachable states
    fn remove_unreachable_states(&mut self) {
        // Find all reachable states through BFS
        let mut reachable = BTreeSet::new();
        let mut queue = Vec::new();

        // Start from the start state(s)
        for &start in &self.start_states {
            queue.push(start);
            reachable.insert(start);
        }

        // BFS to find all reachable states
        while let Some(state) = queue.pop() {
            for targets in self.nodes[state].byte_transitions.values() {
                for &target in targets {
                    if reachable.insert(target) {
                        queue.push(target);
                    }
                }
            }
        }

        // If some states are unreachable, remove them
        if reachable.len() < self.nodes.len() {
            let mut old_to_new = BTreeMap::new();
            let mut new_nodes = Vec::with_capacity(reachable.len());

            // Create mapping from old indices to new indices
            let mut new_idx = 0;
            for state in 0..self.nodes.len() {
                if reachable.contains(&state) {
                    old_to_new.insert(state, new_idx);
                    new_idx += 1;
                }
            }

            // Create new nodes array with only reachable states
            for &old_idx in &reachable {
                let mut node = self.nodes[old_idx].clone();

                // Update the state_id to match its new index in the array
                node.state_id = old_to_new[&old_idx];

                // Update transitions to use new indices
                let mut new_transitions = BTreeMap::new();
                for (byte, targets) in node.byte_transitions {
                    let new_targets = targets
                        .into_iter()
                        .filter_map(|target| old_to_new.get(&target).copied())
                        .collect();

                    new_transitions.insert(byte, new_targets);
                }
                node.byte_transitions = new_transitions;

                // Update capture groups
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
            let mut new_start_states = BTreeSet::new();
            for &state in &self.start_states {
                if let Some(&new_state) = old_to_new.get(&state) {
                    new_start_states.insert(new_state);
                }
            }

            let mut new_accept_states = BTreeSet::new();
            for &state in &self.accept_states {
                if let Some(&new_state) = old_to_new.get(&state) {
                    new_accept_states.insert(new_state);
                }
            }

            // Replace with new data
            self.nodes = new_nodes;
            self.start_states = new_start_states;
            self.accept_states = new_accept_states;
        }
    }
}
