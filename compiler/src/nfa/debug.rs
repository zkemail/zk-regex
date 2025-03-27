use super::NFAGraph;
use std::collections::HashMap;

impl NFAGraph {
    /// Print a detailed view of the NFA for debugging
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
                    let byte_display = format_byte(byte);
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

    /// Print a concise view of the NFA focusing on transitions
    pub fn print_concise(&self) {
        println!("NFAGraph (Concise Format):");
        println!("Start states: {:?}", self.start_states);
        println!("Accept states: {:?}", self.accept_states);
        println!("Transitions:");

        let transitions = self.get_all_transitions_concise();
        let transitions_by_source = group_transitions_by_source(&transitions);
        let mut states: Vec<_> = transitions_by_source.keys().collect();
        states.sort();

        for &state in &states {
            print_state_transitions(self, *state, &transitions_by_source);
        }
    }

    /// Get all transitions in a concise format: (from_state, byte_range, to_state)
    fn get_all_transitions_concise(&self) -> Vec<(usize, (u8, u8), usize)> {
        let mut concise = Vec::new();

        for (state_idx, node) in self.nodes.iter().enumerate() {
            let mut transitions_by_dest: HashMap<usize, Vec<u8>> = HashMap::new();

            // Collect bytes by destination
            for (&byte, destinations) in &node.byte_transitions {
                for &dest in destinations {
                    transitions_by_dest.entry(dest).or_default().push(byte);
                }
            }

            // Convert to ranges
            for (dest, mut bytes) in transitions_by_dest {
                bytes.sort();
                let ranges = bytes_to_ranges(&bytes);
                concise.extend(ranges.into_iter().map(|r| (state_idx, r, dest)));
            }
        }

        concise
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

/// Convert a sorted list of bytes into ranges
fn bytes_to_ranges(bytes: &[u8]) -> Vec<(u8, u8)> {
    let mut ranges = Vec::new();
    if bytes.is_empty() {
        return ranges;
    }

    let mut start = bytes[0];
    let mut prev = start;

    for &byte in &bytes[1..] {
        if byte != prev + 1 {
            ranges.push((start, prev));
            start = byte;
        }
        prev = byte;
    }
    ranges.push((start, prev));

    ranges
}

/// Group transitions by source state
fn group_transitions_by_source(
    transitions: &[(usize, (u8, u8), usize)],
) -> HashMap<usize, Vec<((u8, u8), usize)>> {
    let mut by_source: HashMap<usize, Vec<((u8, u8), usize)>> = HashMap::new();
    for &(from, range, to) in transitions {
        by_source.entry(from).or_default().push((range, to));
    }
    by_source
}

/// Print transitions for a single state
fn print_state_transitions(
    nfa: &NFAGraph,
    state: usize,
    transitions_by_source: &HashMap<usize, Vec<((u8, u8), usize)>>,
) {
    let state_type = if nfa.start_states.contains(&state) {
        if nfa.accept_states.contains(&state) {
            "start+accept"
        } else {
            "start"
        }
    } else if nfa.accept_states.contains(&state) {
        "accept"
    } else {
        "normal"
    };

    println!("  State {} ({}):", state, state_type);

    // Print capture groups if any
    if let Some(node) = nfa.nodes.get(state) {
        if !node.capture_groups.is_empty() {
            println!("    Capture groups: {:?}", node.capture_groups);
        }
    }

    // Print transitions
    if let Some(transitions) = transitions_by_source.get(&state) {
        println!("    Transitions:");

        // Group transitions by destination
        let mut by_dest: HashMap<usize, Vec<(u8, u8)>> = HashMap::new();
        for &(range, dest) in transitions {
            by_dest.entry(dest).or_default().push(range);
        }

        let mut dests: Vec<_> = by_dest.keys().collect();
        dests.sort();

        for &dest in &dests {
            let ranges = &by_dest[&dest];
            print!("      -> {}: ", dest);

            let range_strs: Vec<_> = ranges
                .iter()
                .map(|&(start, end)| {
                    if start == end {
                        format_byte(start)
                    } else {
                        format!("{}-{}", format_byte(start), format_byte(end))
                    }
                })
                .collect();

            println!("{}", range_strs.join(", "));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bytes_to_ranges() {
        assert_eq!(bytes_to_ranges(&[1, 2, 3, 5, 6, 9]), vec![
            (1, 3),
            (5, 6),
            (9, 9)
        ]);
        assert_eq!(bytes_to_ranges(&[1]), vec![(1, 1)]);
        assert!(bytes_to_ranges(&[]).is_empty());
    }

    #[test]
    fn test_format_byte() {
        assert_eq!(format_byte(b'a'), "97 ('a')");
        assert_eq!(format_byte(0), "0");
    }
}
