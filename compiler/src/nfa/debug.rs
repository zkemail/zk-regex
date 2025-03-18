use std::collections::HashMap;
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
                if self.accept_states.contains(&idx) {
                    "start+accept"
                } else {
                    "start"
                }
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

    /// Get all valid transitions in the form (curr_state, byte_range, next_state)
    pub fn get_all_transitions_concise(&self) -> Vec<(usize, (u8, u8), usize)> {
        let mut concise_transitions = Vec::new();

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

                // Add the ranges to the result
                for (start, end) in ranges {
                    concise_transitions.push((state_idx, (start, end), dest));
                }
            }
        }

        concise_transitions
    }

    /// Print the NFA in a concise format
    pub fn print_concise(&self) {
        println!("NFAGraph (Concise Format):");
        println!("Start states: {:?}", self.start_states);
        println!("Accept states: {:?}", self.accept_states);
        println!("Transitions:");

        let transitions = self.get_all_transitions_concise();

        // Group transitions by source state
        let mut transitions_by_source = HashMap::new();
        for &(from, range, to) in &transitions {
            transitions_by_source
                .entry(from)
                .or_insert_with(Vec::new)
                .push((range, to));
        }

        // Print transitions for each state
        let mut states: Vec<_> = transitions_by_source.keys().collect();
        states.sort();

        for &state in &states {
            let state_type = if self.start_states.contains(&state) {
                if self.accept_states.contains(&state) {
                    "start+accept"
                } else {
                    "start"
                }
            } else if self.accept_states.contains(&state) {
                "accept"
            } else {
                "normal"
            };

            println!("  State {} ({}):", state, state_type);

            if let Some(node) = self.nodes.get(*state) {
                // Print capture groups if any
                if !node.capture_groups.is_empty() {
                    println!("    Capture groups: {:?}", node.capture_groups);
                }
            }

            // Print transitions
            if let Some(transitions) = transitions_by_source.get(&state) {
                println!("    Transitions:");

                // Group transitions by destination
                let mut by_dest = HashMap::new();
                for &(range, dest) in transitions {
                    by_dest.entry(dest).or_insert_with(Vec::new).push(range);
                }

                // Print transitions for each destination
                let mut dests: Vec<_> = by_dest.keys().collect();
                dests.sort();

                for &dest in &dests {
                    let ranges = &by_dest[&dest];
                    print!("      -> {}: ", dest);

                    let mut range_strs = Vec::new();
                    for &(start, end) in ranges {
                        if start == end {
                            // Single byte
                            range_strs.push(format_byte(start));
                        } else {
                            // Range of bytes
                            range_strs.push(format!("{}-{}", format_byte(start), format_byte(end)));
                        }
                    }

                    println!("{}", range_strs.join(", "));
                }
            }
        }
    }

    /// Get statistics about the NFA for circuit estimation
    pub fn get_stats(&self) -> NFAStats {
        let transitions = self.get_all_transitions_concise();

        // Count unique states
        let mut states = HashSet::new();
        for &(from, _, to) in &transitions {
            states.insert(from);
            states.insert(to);
        }

        // Count total byte coverage in transitions
        let mut byte_count = 0;
        for &(_, (start, end), _) in &transitions {
            byte_count += ((end as u32) - (start as u32) + 1) as usize;
        }

        // Count unique byte ranges
        let range_count = transitions.len();

        NFAStats {
            state_count: states.len(),
            transition_count: range_count,
            byte_coverage: byte_count,
            start_state_count: self.start_states.len(),
            accept_state_count: self.accept_states.len(),
        }
    }

    /// Print transitions with capture group information
    pub fn print_transitions_for_circom(&self) {
        println!("NFA Transitions for Circom Template:");
        println!("Start states: {:?}", self.start_states);
        println!("Accept states: {:?}", self.accept_states);
        println!(
            "Transitions (curr_state, byte_start, byte_end, next_state, capture_group_id, capture_group_start):"
        );

        let transitions = self.get_transitions_with_capture_info();

        for (curr_state, byte_start, byte_end, next_state, capture_info) in transitions {
            let state_type = if self.start_states.contains(&curr_state) {
                if self.accept_states.contains(&curr_state) {
                    "start+accept"
                } else {
                    "start"
                }
            } else if self.accept_states.contains(&curr_state) {
                "accept"
            } else {
                "normal"
            };

            let dest_type = if self.accept_states.contains(&next_state) {
                "accept"
            } else {
                "normal"
            };

            if byte_start == byte_end {
                // Single byte transition
                if let Some((capture_id, is_start)) = capture_info {
                    println!(
                        "  ({} ({}), {}, {} ({}), {}, {})",
                        curr_state,
                        state_type,
                        byte_start,
                        next_state,
                        dest_type,
                        capture_id,
                        is_start
                    );
                } else {
                    println!(
                        "  ({} ({}), {}, {} ({}), None)",
                        curr_state, state_type, byte_start, next_state, dest_type
                    );
                }
            } else {
                // Byte range transition
                if let Some((capture_id, is_start)) = capture_info {
                    println!(
                        "  ({} ({}), {}-{}, {} ({}), {}, {})",
                        curr_state,
                        state_type,
                        byte_start,
                        byte_end,
                        next_state,
                        dest_type,
                        capture_id,
                        is_start
                    );
                } else {
                    println!(
                        "  ({} ({}), {}-{}, {} ({}), None)",
                        curr_state, state_type, byte_start, byte_end, next_state, dest_type
                    );
                }
            }
        }
    }
}

/// Format a byte as a readable string
fn format_byte(byte: u8) -> String {
    if byte.is_ascii_graphic() || byte == b' ' {
        format!("{} ('{}')", byte, byte as char)
    } else {
        format!("{}", byte)
    }
}

/// Statistics about an NFA for circuit estimation
#[derive(Debug, Clone)]
pub struct NFAStats {
    pub state_count: usize,
    pub transition_count: usize,
    pub byte_coverage: usize,
    pub start_state_count: usize,
    pub accept_state_count: usize,
}
