use super::NFAGraph;
use crate::nfa::error::{ NFABuildError, NFAResult };
use std::collections::{ HashMap, HashSet };

// Each step in the path contains:
// (current_state, next_state, byte, Option<(capture_group_id, capture_group_start)>)
pub type PathStep = (usize, usize, u8, Option<(usize, bool)>);
pub type PathTraversal = Vec<PathStep>;

impl NFAGraph {
    /// Get all transitions in the form (curr_state, byte, next_state)
    pub fn get_all_transitions(&self) -> Vec<(usize, u8, usize)> {
        let mut transitions = Vec::new();
        for (state_idx, node) in self.nodes.iter().enumerate() {
            for (&byte, destinations) in &node.byte_transitions {
                for &next_state in destinations {
                    transitions.push((state_idx, byte, next_state));
                }
            }
        }
        transitions
    }

    /// Get transitions with capture group information
    pub fn get_transitions_with_capture_info(
        &self
    ) -> Vec<(usize, u8, usize, Option<(usize, bool)>)> {
        let mut transitions = Vec::new();
        for (state_idx, node) in self.nodes.iter().enumerate() {
            for (&byte, destinations) in &node.byte_transitions {
                for &next_state in destinations {
                    // Get capture group for this transition if it exists
                    let capture = node.capture_groups.first().copied();
                    transitions.push((state_idx, byte, next_state, capture));
                }
            }
        }
        transitions
    }

    /// Check if a state is reachable from any start state
    pub fn is_state_reachable(&self, target: usize) -> bool {
        let mut visited = HashSet::new();
        let mut stack: Vec<usize> = Vec::new();

        // Start from all start states
        stack.extend(&self.start_states);

        while let Some(state) = stack.pop() {
            if state == target {
                return true;
            }

            if visited.insert(state) {
                // Add all states reachable through byte transitions
                for destinations in self.nodes[state].byte_transitions.values() {
                    stack.extend(destinations.as_slice());
                }
            }
        }

        false
    }

    /// Get all states that can reach accept states
    pub fn get_states_reaching_accept(&self) -> HashSet<usize> {
        let mut reaching_accept = HashSet::new();
        let mut reverse_edges: HashMap<usize, Vec<usize>> = HashMap::new();

        // Build reverse graph
        for (state_idx, node) in self.nodes.iter().enumerate() {
            for destinations in node.byte_transitions.values() {
                for &dest in destinations {
                    reverse_edges.entry(dest).or_default().push(state_idx);
                }
            }
        }

        // Start from accept states
        let mut stack: Vec<_> = self.accept_states.iter().copied().collect();
        while let Some(state) = stack.pop() {
            if reaching_accept.insert(state) {
                if let Some(predecessors) = reverse_edges.get(&state) {
                    stack.extend(predecessors);
                }
            }
        }

        reaching_accept
    }

    /// Verify the NFA's structural integrity
    pub fn verify(&self) -> NFAResult<()> {
        // Check state indices
        for (idx, node) in self.nodes.iter().enumerate() {
            if node.state_id != idx {
                return Err(
                    NFABuildError::InvalidStateId(format!("State ID mismatch at index {}", idx))
                );
            }
        }

        // Check transition validity
        for (state_idx, node) in self.nodes.iter().enumerate() {
            for destinations in node.byte_transitions.values() {
                for &dest in destinations {
                    if dest >= self.nodes.len() {
                        return Err(
                            NFABuildError::InvalidTransition(
                                format!(
                                    "Invalid transition target {} from state {}",
                                    dest,
                                    state_idx
                                )
                            )
                        );
                    }
                }
            }
        }

        // Check start states validity
        for &start in &self.start_states {
            if start >= self.nodes.len() {
                return Err(NFABuildError::InvalidStateId(format!("Invalid start state {}", start)));
            }
        }

        // Check accept states validity
        for &accept in &self.accept_states {
            if accept >= self.nodes.len() {
                return Err(
                    NFABuildError::InvalidStateId(format!("Invalid accept state {}", accept))
                );
            }
        }

        Ok(())
    }

    pub fn generate_path_traversal(&self, haystack: &[u8]) -> NFAResult<PathTraversal> {
        let mut path = Vec::with_capacity(haystack.len());
        let mut current_state = *self.start_states
            .iter()
            .next()
            .ok_or(NFABuildError::Build("No start state found".into()))?;

        for (i, &byte) in haystack.iter().enumerate() {
            if let Some(transitions) = self.nodes[current_state].byte_transitions.get(&byte) {
                if let Some(&next_state) = transitions.first() {
                    let capture_info = self.nodes[current_state].capture_groups.first().copied();

                    path.push((current_state, next_state, byte, capture_info));

                    current_state = next_state;
                } else {
                    return Err(
                        NFABuildError::Build(format!("No valid transition found at position {}", i))
                    );
                }
            } else {
                return Err(
                    NFABuildError::Build(
                        format!("No transition found for byte {} at position {}", byte, i)
                    )
                );
            }
        }

        if !self.accept_states.contains(&current_state) {
            return Err(NFABuildError::Build("Path does not end in accept state".into()));
        }

        Ok(path)
    }
}
