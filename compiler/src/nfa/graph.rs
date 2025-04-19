use regex_automata::{Input, nfa::thompson::pikevm::PikeVM};

use super::NFAGraph;
use crate::nfa::error::{NFAError, NFAResult};
use std::collections::{HashMap, HashSet};

// Each step in the path contains:
// (current_state, next_state, byte, Option<(capture_group_id, capture_group_start)>)
pub type PathStep = (usize, usize, u8, Option<(usize, bool)>);
pub type TraversalPath = Vec<PathStep>;

pub struct PathWithMatchSpan {
    pub path: TraversalPath,
    pub span: (usize, usize), // (start, length)
}

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
        &self,
    ) -> Vec<(usize, u8, usize, Option<(usize, bool)>)> {
        let mut transitions = Vec::new();
        for (state_idx, node) in self.nodes.iter().enumerate() {
            for (&byte, destinations) in &node.byte_transitions {
                for &next_state in destinations {
                    // Get capture group for this transition if it exists
                    let capture = if let Some(captures) = node.capture_groups.get(&next_state) {
                        captures.first().copied()
                    } else {
                        None
                    };
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
                    stack.extend(destinations.iter());
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
                return Err(NFAError::InvalidStateId(format!(
                    "State ID mismatch at index {}",
                    idx
                )));
            }
        }

        // Check transition validity
        for (state_idx, node) in self.nodes.iter().enumerate() {
            for destinations in node.byte_transitions.values() {
                for &dest in destinations {
                    if dest >= self.nodes.len() {
                        return Err(NFAError::InvalidTransition(format!(
                            "Invalid transition target {} from state {}",
                            dest, state_idx
                        )));
                    }
                }
            }
        }

        // Check start states validity
        for &start in &self.start_states {
            if start >= self.nodes.len() {
                return Err(NFAError::InvalidStateId(format!(
                    "Invalid start state {}",
                    start
                )));
            }
        }

        // Check accept states validity
        for &accept in &self.accept_states {
            if accept >= self.nodes.len() {
                return Err(NFAError::InvalidStateId(format!(
                    "Invalid accept state {}",
                    accept
                )));
            }
        }

        Ok(())
    }

    /// Get the path to the accept state for a given haystack
    pub fn get_path_to_accept(&self, haystack: &[u8]) -> NFAResult<PathWithMatchSpan> {
        let vm = PikeVM::new(&self.regex)
            .map_err(|e| NFAError::RegexCompilation(format!("Failed to build VM: {}", e)))?;
        let mut cache = vm.create_cache();
        let mat = vm
            .find(&mut cache, Input::new(haystack))
            .ok_or_else(|| NFAError::NoMatch("No match found".into()))?;

        let matched_bytes = &haystack[mat.range()];
        let mut paths: HashMap<usize, TraversalPath> = HashMap::new();

        // Start with all defined start states
        for &start_state in &self.start_states {
            paths.insert(start_state, Vec::new());
        }

        if paths.is_empty() {
            return Err(NFAError::NoMatch(
                "No start states defined in the NFA".into(),
            ));
        }

        for &byte in matched_bytes {
            let mut new_paths = HashMap::new();

            // For each current path
            for (state, path) in paths {
                // Get all possible transitions for this byte
                if let Some(transitions) = self.nodes[state].byte_transitions.get(&byte) {
                    // Branch out to each possible next state
                    for &next_state in transitions {
                        let mut new_path = path.clone();
                        let capture = self.nodes[state]
                            .capture_groups
                            .get(&next_state)
                            .and_then(|caps| caps.first().copied());

                        new_path.push((state, next_state, byte, capture));
                        new_paths.insert(next_state, new_path);
                    }
                }
            }

            // If no valid transitions found
            if new_paths.is_empty() {
                return Err(NFAError::NoValidPath("No valid transitions found".into()));
            }

            paths = new_paths;
        }

        // Find any path that reached an accept state
        for (state, path) in paths {
            if self.accept_states.contains(&state) {
                return Ok(PathWithMatchSpan {
                    path,
                    span: (mat.start(), mat.end() - mat.start()),
                });
            }
        }

        Err(NFAError::NoValidPath("No path reached accept state".into()))
    }
}
