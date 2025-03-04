use std::collections::HashSet;

use super::NFAGraph;

impl NFAGraph {
    /// Print the NFA for debugging
    pub fn print(&self) {
        println!("NFAGraph:");
        println!("Start states: {:?}", self.start_states);
        println!("Accept states: {:?}", self.accept_states);
        println!("Nodes:");

        for (idx, node) in self.nodes.iter().enumerate() {
            let state_type = if self.start_states.contains(&idx) {
                if self.accept_states.contains(&idx) { "start+accept" } else { "start" }
            } else if self.accept_states.contains(&idx) {
                "accept"
            } else {
                "normal"
            };

            println!("  Node {idx} ({state_type}):");

            // Print byte transitions
            if !node.byte_transitions.is_empty() {
                println!("    Byte transitions:");
                for (&byte, destinations) in &node.byte_transitions {
                    let byte_display = if byte.is_ascii_graphic() || byte == b' ' {
                        format!("{} ('{}')", byte, byte as char)
                    } else {
                        format!("{}", byte)
                    };
                    println!("      {byte_display} -> {:?}", destinations);
                }
            }

            // Print epsilon transitions
            if !node.epsilon_transitions.is_empty() {
                println!("    Epsilon transitions: {:?}", node.epsilon_transitions);
            }

            // Print capture groups
            if !node.capture_groups.is_empty() {
                println!("    Capture groups: {:?}", node.capture_groups);
            }
        }
    }

    /// Get all valid transitions in the form (curr_state, byte, next_state)
    pub fn get_all_transitions(&self) -> Vec<(usize, u8, usize)> {
        let mut transitions = Vec::new();

        // Add all byte transitions
        for (state_idx, node) in self.nodes.iter().enumerate() {
            for (&byte, destinations) in &node.byte_transitions {
                for &next_state in destinations {
                    transitions.push((state_idx, byte, next_state));
                }
            }
        }

        transitions
    }

    /// Get the total number of transitions
    pub fn count_transitions(&self) -> usize {
        self.get_all_transitions().len()
    }

    /// Get statistics about the NFA for circuit estimation
    pub fn get_stats(&self) -> NFAStats {
        let transitions = self.get_all_transitions();

        // Count unique states
        let mut states = HashSet::new();
        for &(from, _, to) in &transitions {
            states.insert(from);
            states.insert(to);
        }

        // Count unique bytes used in transitions
        let mut bytes = HashSet::new();
        for &(_, byte, _) in &transitions {
            bytes.insert(byte);
        }

        NFAStats {
            state_count: states.len(),
            transition_count: transitions.len(),
            unique_byte_count: bytes.len(),
            start_state_count: self.start_states.len(),
            accept_state_count: self.accept_states.len(),
        }
    }
}

/// Statistics about an NFA for circuit estimation
#[derive(Debug, Clone)]
pub struct NFAStats {
    pub state_count: usize,
    pub transition_count: usize,
    pub unique_byte_count: usize,
    pub start_state_count: usize,
    pub accept_state_count: usize,
}
