use super::NFAGraph;
use std::collections::{HashMap, HashSet, VecDeque};

impl NFAGraph {
    /// Remove epsilon transitions from the NFA
    pub(crate) fn remove_epsilon_transitions(&mut self) {
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

        *self = new_graph;
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

    /// Check if the NFA accepts a string and returns the traversal path
    pub fn accepts_with_path(
        &self,
        input: &[u8],
    ) -> Option<Vec<(usize, u8, usize, Option<(usize, bool)>)>> {
        println!("Searching in input: {:?}", String::from_utf8_lossy(input));

        for start_pos in 0..input.len() {
            println!("\nTrying start position {}", start_pos);
            let mut current_states = self.start_states.clone();
            println!("Starting states: {:?}", current_states);

            let mut state_paths: HashMap<usize, Vec<(usize, u8, usize, Option<(usize, bool)>)>> =
                HashMap::new();
            for &state in &current_states {
                state_paths.insert(state, Vec::new());
            }

            let mut last_accepting_path = None;

            for (i, &byte) in input[start_pos..].iter().enumerate() {
                println!(
                    "\n  Processing byte '{}' at position {}",
                    byte as char,
                    start_pos + i
                );
                let mut next_states = HashSet::new();
                let mut new_state_paths = HashMap::new();

                for &curr_state in &current_states {
                    if let Some(node) = self.nodes.get(curr_state) {
                        if let Some(destinations) = node.byte_transitions.get(&byte) {
                            for &next_state in destinations {
                                next_states.insert(next_state);
                                let capture_info = if !node.capture_groups.is_empty() {
                                    Some(node.capture_groups[0])
                                } else {
                                    None
                                };
                                let mut new_path = state_paths[&curr_state].clone();
                                new_path.push((curr_state, byte, next_state, capture_info));
                                new_state_paths.insert(next_state, new_path.clone());

                                // Update last accepting path if this is an accept state
                                if self.accept_states.contains(&next_state) {
                                    last_accepting_path = Some(new_path.clone());
                                }
                            }
                        }
                    }
                }

                if next_states.is_empty() {
                    break;
                }

                current_states = next_states;
                state_paths = new_state_paths;
            }

            // Return the last accepting path found from this start position
            if last_accepting_path.is_some() {
                return last_accepting_path;
            }
        }
        None
    }
}
