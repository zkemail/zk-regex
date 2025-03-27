use super::NFAGraph;
use crate::nfa::error::{ NFABuildError, NFAResult };
use std::collections::{ BTreeSet, HashMap };

/// Represents a closure of states reachable through epsilon transitions
#[derive(Debug)]
struct EpsilonClosure {
    /// States reachable through epsilon transitions
    states: BTreeSet<usize>,
    /// Captures encountered along epsilon paths: (state_id, (group_id, is_start))
    captures: Vec<(usize, (usize, bool))>,
    /// Whether this closure contains an accept state
    is_accept: bool,
}

impl NFAGraph {
    /// Removes epsilon transitions from the NFA while preserving its behavior.
    ///
    /// This process:
    /// 1. Computes epsilon closures for all states
    /// 2. Creates direct byte transitions that bypass epsilon transitions
    /// 3. Preserves capture group information
    /// 4. Updates start and accept states
    /// 5. Removes unreachable states
    pub fn remove_epsilon_transitions(&mut self) -> NFAResult<()> {
        let mut new_transitions = Vec::with_capacity(self.nodes.len());
        let mut new_captures = Vec::with_capacity(self.nodes.len());
        let mut new_accept_states = BTreeSet::new();

        // Process each state
        for state in 0..self.nodes.len() {
            let closure = self.compute_epsilon_closure(state)?;

            // Collect byte transitions and their associated captures
            let mut byte_transitions: HashMap<u8, BTreeSet<usize>> = HashMap::new();
            let mut transition_captures: HashMap<(u8, usize), Vec<(usize, bool)>> = HashMap::new();

            // Process each state in the epsilon closure
            for &r_state in &closure.states {
                if r_state >= self.nodes.len() {
                    return Err(
                        NFABuildError::InvalidStateId(
                            format!("Invalid state {} in epsilon closure", r_state)
                        )
                    );
                }

                // Add captures that occur before this state
                let state_captures: Vec<_> = closure.captures
                    .iter()
                    .filter(|(s, _)| *s == r_state)
                    .map(|(_, cap)| *cap)
                    .collect();

                // Process byte transitions
                for (&byte, targets) in &self.nodes[r_state].byte_transitions {
                    let entry = byte_transitions.entry(byte).or_default();
                    entry.extend(targets);

                    // Associate captures with transitions
                    for &target in targets {
                        if target >= self.nodes.len() {
                            return Err(
                                NFABuildError::InvalidTransition(
                                    format!(
                                        "Invalid transition target {} from state {}",
                                        target,
                                        r_state
                                    )
                                )
                            );
                        }
                        transition_captures
                            .entry((byte, target))
                            .or_default()
                            .extend(state_captures.iter().copied());
                    }
                }
            }

            // Add self-loop for state 0 (unanchored start)
            if state == 0 {
                for byte in 0..=255 {
                    byte_transitions.entry(byte).or_default().insert(0);
                }
            }

            new_transitions.push(byte_transitions);
            new_captures.push(transition_captures);

            // If any state in the closure is an accept state, this state becomes an accept state
            if closure.is_accept {
                new_accept_states.insert(state);
            }
        }

        // Apply new transitions and captures
        for (state, (transitions, captures)) in new_transitions
            .into_iter()
            .zip(new_captures.into_iter())
            .enumerate() {
            self.nodes[state].byte_transitions = transitions
                .into_iter()
                .map(|(k, v)| (k, v.into_iter().collect()))
                .collect();

            self.nodes[state].capture_groups = captures
                .into_iter()
                .flat_map(|(_, caps)| caps)
                .collect();

            self.nodes[state].epsilon_transitions.clear();
        }

        // Update accept states before pruning
        self.accept_states = new_accept_states.into_iter().collect();

        self.prune_unreachable()?;
        Ok(())
    }

    /// Computes the epsilon closure for a given state
    fn compute_epsilon_closure(&self, start: usize) -> NFAResult<EpsilonClosure> {
        if start >= self.nodes.len() {
            return Err(
                NFABuildError::InvalidStateId(
                    format!("Invalid start state {} for epsilon closure", start)
                )
            );
        }

        let mut closure = EpsilonClosure {
            states: BTreeSet::new(),
            captures: Vec::new(),
            is_accept: false,
        };

        let mut visited = BTreeSet::new();
        self.follow_epsilon(start, &mut visited, &mut closure)?;

        Ok(closure)
    }

    /// Recursively follows epsilon transitions to build the closure
    fn follow_epsilon(
        &self,
        state: usize,
        visited: &mut BTreeSet<usize>,
        closure: &mut EpsilonClosure
    ) -> NFAResult<()> {
        if state >= self.nodes.len() {
            return Err(
                NFABuildError::InvalidStateId(format!("Invalid state {} in epsilon path", state))
            );
        }

        if !visited.insert(state) {
            return Ok(());
        }

        closure.states.insert(state);

        // Check if this state is an accept state
        if self.accept_states.contains(&state) {
            closure.is_accept = true;
        }

        // Add captures for this state
        for &capture in &self.nodes[state].capture_groups {
            closure.captures.push((state, capture));
        }

        // Follow epsilon transitions
        for &next in &self.nodes[state].epsilon_transitions {
            self.follow_epsilon(next, visited, closure)?;
        }

        Ok(())
    }

    /// Removes unreachable states and renumbers remaining states
    fn prune_unreachable(&mut self) -> NFAResult<()> {
        // Find all reachable states starting from start states
        let mut reachable = BTreeSet::new();
        let mut stack = Vec::new();

        // Add start states to stack
        for &start in &self.start_states {
            stack.push(start);
            reachable.insert(start);
        }

        // DFS to find all reachable states
        while let Some(state) = stack.pop() {
            for targets in self.nodes[state].byte_transitions.values() {
                for &target in targets {
                    if reachable.insert(target) {
                        stack.push(target);
                    }
                }
            }
        }

        // Create new nodes array with only reachable states
        let mut new_nodes = Vec::new();
        let mut old_to_new = vec![None; self.nodes.len()];

        // Map old indices to new ones
        for (new_idx, &old_idx) in reachable.iter().enumerate() {
            old_to_new[old_idx] = Some(new_idx);
            let mut node = self.nodes[old_idx].clone();
            node.state_id = new_idx;
            new_nodes.push(node);
        }

        // Update transitions in new nodes to use new indices
        for node in &mut new_nodes {
            for targets in node.byte_transitions.values_mut() {
                *targets = targets
                    .iter()
                    .filter_map(|&t| old_to_new[t])
                    .collect();
            }
        }

        // Update start and accept states
        self.start_states = self.start_states
            .iter()
            .filter_map(|&s| old_to_new[s])
            .collect();

        self.accept_states = self.accept_states
            .iter()
            .filter_map(|&s| old_to_new[s])
            .collect();

        // Replace old nodes with new ones
        self.nodes = new_nodes;
        Ok(())
    }
}
