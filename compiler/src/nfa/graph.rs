use super::NFAGraph;
use std::collections::{HashMap, HashSet, VecDeque};

impl NFAGraph {
    /// Remove epsilon transitions from the NFA
    pub fn remove_epsilon_transitions(&self) -> Self {
        let mut new_graph = self.clone();

        // Step 1: Compute epsilon closure for all states
        let epsilon_closures = self.compute_all_epsilon_closures();

        // Step 2: Duplicate all moves from epsilon-reachable states and merge properties
        for node_idx in 0..self.nodes.len() {
            let closure = &epsilon_closures[node_idx];

            // Create a new transitions map for this state
            let mut new_transitions = HashMap::new();

            // For each state in the epsilon closure
            for &closure_state in closure {
                // Skip the state itself (already handled)
                if closure_state == node_idx {
                    continue;
                }

                // Merge properties from epsilon-reachable states
                if let Some(node) = self.nodes.get(closure_state) {
                    // Merge capture groups
                    for &capture_group in &node.capture_groups {
                        if !new_graph.nodes[node_idx]
                            .capture_groups
                            .contains(&capture_group)
                        {
                            new_graph.nodes[node_idx].capture_groups.push(capture_group);
                        }
                    }

                    // Add all byte transitions from the closure state
                    for (&byte, destinations) in &node.byte_transitions {
                        for &dest in destinations {
                            new_transitions
                                .entry(byte)
                                .or_insert_with(Vec::new)
                                .push(dest);
                        }
                    }
                }
            }

            // Merge the new transitions with existing ones
            for (byte, destinations) in new_transitions {
                for dest in destinations {
                    if !new_graph.nodes[node_idx]
                        .byte_transitions
                        .entry(byte)
                        .or_insert_with(Vec::new)
                        .contains(&dest)
                    {
                        new_graph.nodes[node_idx]
                            .byte_transitions
                            .get_mut(&byte)
                            .unwrap()
                            .push(dest);
                    }
                }
            }
        }

        // Step 3: Make epsilon-reachable start states also start states
        let mut new_start_states = self.start_states.clone();
        for &start_state in &self.start_states {
            for &reachable in &epsilon_closures[start_state] {
                new_start_states.insert(reachable);
            }
        }
        new_graph.start_states = new_start_states;

        // Step 4: Make states with epsilon-reachable accept states also accept states
        let mut new_accept_states = HashSet::new();
        for node_idx in 0..self.nodes.len() {
            for &reachable in &epsilon_closures[node_idx] {
                if self.accept_states.contains(&reachable) {
                    new_accept_states.insert(node_idx);
                    break;
                }
            }
        }
        new_graph.accept_states = new_accept_states;

        // Remove unreachable states from accept states
        let mut reachable_states = HashSet::new();
        // Add all start states
        reachable_states.extend(&new_graph.start_states);

        // Find all states reachable through byte transitions
        let mut queue: VecDeque<usize> = new_graph.start_states.iter().cloned().collect();
        while let Some(state) = queue.pop_front() {
            if let Some(node) = new_graph.nodes.get(state) {
                for destinations in node.byte_transitions.values() {
                    for &dest in destinations {
                        if reachable_states.insert(dest) {
                            queue.push_back(dest);
                        }
                    }
                }
            }
        }

        // Keep only reachable states in accept states
        new_graph
            .accept_states
            .retain(|&state| reachable_states.contains(&state));

        // Clear all epsilon transitions
        for node in &mut new_graph.nodes {
            node.epsilon_transitions.clear();
        }

        // Remove duplicates in transition lists
        for node in &mut new_graph.nodes {
            for destinations in node.byte_transitions.values_mut() {
                destinations.sort();
                destinations.dedup();
            }
        }

        new_graph
    }

    /// Compute epsilon closures for all states
    fn compute_all_epsilon_closures(&self) -> Vec<Vec<usize>> {
        let mut closures = Vec::with_capacity(self.nodes.len());

        for node_idx in 0..self.nodes.len() {
            closures.push(self.compute_epsilon_closure(node_idx));
        }

        closures
    }

    /// Compute epsilon closure for a single state
    fn compute_epsilon_closure(&self, start_idx: usize) -> Vec<usize> {
        let mut closure = Vec::new();
        let mut visited = HashSet::new();
        let mut queue = VecDeque::new();

        // Add the start state to the queue and mark it as visited
        queue.push_back(start_idx);
        visited.insert(start_idx);
        closure.push(start_idx);

        // BFS to find all epsilon-reachable states
        while let Some(current) = queue.pop_front() {
            if let Some(node) = self.nodes.get(current) {
                for &epsilon_dest in &node.epsilon_transitions {
                    if visited.insert(epsilon_dest) {
                        closure.push(epsilon_dest);
                        queue.push_back(epsilon_dest);
                    }
                }
            }
        }

        closure
    }

    /// Check if the NFA accepts a string
    pub fn accepts(&self, input: &[u8]) -> bool {
        let mut current_states = self.start_states.clone();

        for &byte in input {
            let mut next_states = HashSet::new();

            for &state in &current_states {
                if let Some(node) = self.nodes.get(state) {
                    if let Some(destinations) = node.byte_transitions.get(&byte) {
                        next_states.extend(destinations);
                    }
                }
            }

            if next_states.is_empty() {
                return false;
            }

            current_states = next_states;
        }

        // Check if any current state is an accept state
        current_states
            .iter()
            .any(|&state| self.accept_states.contains(&state))
    }
}
