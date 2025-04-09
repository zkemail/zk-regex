use super::{NFAGraph, NFAResult};
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

        // Handle start states
        for &start in &self.start_states {
            new_start_states.insert(start);
            new_start_states.extend(&closures[start].states);
        }

        for (state, closure) in closures.iter().enumerate() {
            if closure.is_accept {
                new_accept_states.insert(state);
            }

            // For each reachable state via epsilon
            for &r_state in &closure.states {
                for (&byte, targets) in &self.nodes[r_state].byte_transitions {
                    // Add the transition
                    new_transitions[state]
                        .entry(byte)
                        .or_insert_with(BTreeSet::new)
                        .extend(targets);

                    // If r_state had captures, they belong to the target states
                    for &target in targets {
                        for &(capture_state, capture) in &closure.captures {
                            if capture_state == r_state {
                                new_captures[state]
                                    .entry(target)
                                    .or_insert_with(BTreeSet::new)
                                    .insert(capture);
                            }
                        }
                    }
                }
            }
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
}
