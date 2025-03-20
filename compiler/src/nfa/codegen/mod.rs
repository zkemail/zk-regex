mod circom;
mod noir;

use std::collections::HashMap;

use crate::nfa::NFAGraph;

impl NFAGraph {
    /// Get all transitions with capture group information
    pub fn get_transitions_with_capture_info(
        &self,
    ) -> Vec<(usize, u8, u8, usize, Option<(usize, bool)>)> {
        let mut transitions = Vec::new();

        // Process each state
        for (state_idx, node) in self.nodes.iter().enumerate() {
            // Group transitions by destination state
            let mut transitions_by_dest: HashMap<usize, Vec<u8>> = HashMap::new();

            // Collect all bytes for each destination
            for (&byte, destinations) in &node.byte_transitions {
                for &dest in destinations {
                    transitions_by_dest.entry(dest).or_default().push(byte);
                }
            }

            // For each destination, find contiguous byte ranges
            for (dest, mut bytes) in transitions_by_dest {
                bytes.sort();

                // Find contiguous ranges
                let mut ranges = Vec::new();
                if !bytes.is_empty() {
                    let mut start = bytes[0];
                    let mut end = bytes[0];

                    for i in 1..bytes.len() {
                        if bytes[i] == end + 1 {
                            // Continue the current range
                            end = bytes[i];
                        } else {
                            // End the current range and start a new one
                            ranges.push((start, end));
                            start = bytes[i];
                            end = bytes[i];
                        }
                    }

                    // Add the last range
                    ranges.push((start, end));
                }

                // Get capture group info for this state
                let capture_info = if !node.capture_groups.is_empty() {
                    // Instead of just using the first capture group, we'll handle all of them
                    // by creating separate transitions for each capture group
                    for (start, end) in ranges.clone() {
                        for &capture_group in &node.capture_groups[1..] {
                            transitions.push((state_idx, start, end, dest, Some(capture_group)));
                        }
                    }
                    // Return the first capture group for the main transition
                    Some(node.capture_groups[0])
                } else {
                    None
                };

                // Add the ranges to the result
                for (start, end) in ranges {
                    transitions.push((state_idx, start, end, dest, capture_info));
                }
            }
        }

        transitions
    }

    /// Generate circuit transition data
    pub fn generate_circuit_data(
        &self,
    ) -> (
        Vec<usize>,
        Vec<usize>,
        Vec<(usize, u8, u8, usize, Option<(usize, bool)>)>,
    ) {
        let start_states = self.start_states.iter().cloned().collect();
        let accept_states = self.accept_states.iter().cloned().collect();
        let transitions = self.get_transitions_with_capture_info();

        (start_states, accept_states, transitions)
    }
}