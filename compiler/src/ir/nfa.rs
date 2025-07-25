//! Final NFA representation for circuit generation
//!
//! This module contains the final, circuit-ready NFA representation.
//! All epsilon transitions have been eliminated and the structure is
//! optimized for circuit generation.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

use crate::passes::{NFAError, NFAResult};

/// Final NFA node (no epsilon transitions)
///
/// This represents a state in the final NFA that is ready for circuit generation.
/// All epsilon transitions have been eliminated during the compilation process.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct NFANode {
    /// Unique identifier for this state
    pub state_id: usize,

    /// Byte-consuming transitions: byte -> set of target states
    pub byte_transitions: BTreeMap<u8, BTreeSet<usize>>,

    /// Capture group information: target_state -> capture_events
    /// Each capture event is (group_id, is_start_of_group)
    pub capture_groups: BTreeMap<usize, BTreeSet<(usize, bool)>>,
}

impl NFANode {
    /// Check if this node represents an anchor state (start/end of string)
    pub fn is_anchor(&self) -> bool {
        // In our representation, anchor information is implicit in the graph structure
        // Start states are tracked in NFAGraph.start_states
        // Accept states are tracked in NFAGraph.accept_states
        false
    }
}

/// Final NFA representation ready for circuit generation
///
/// This is the final output of the compilation pipeline. It contains no epsilon
/// transitions and is optimized for conversion to arithmetic circuits.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct NFAGraph {
    /// The original regex pattern
    pub regex: String,

    /// All states in the final NFA (no epsilon transitions)
    pub nodes: Vec<NFANode>,

    /// Set of start state indices
    pub start_states: BTreeSet<usize>,

    /// Set of accept state indices
    pub accept_states: BTreeSet<usize>,

    /// Number of capture groups in the regex
    pub num_capture_groups: usize,
}

impl NFAGraph {
    /// Create a new empty NFA graph
    pub fn new(regex: String) -> Self {
        Self {
            regex,
            nodes: Vec::new(),
            start_states: BTreeSet::new(),
            accept_states: BTreeSet::new(),
            num_capture_groups: 0,
        }
    }

    /// Serialize the NFA graph to JSON
    pub fn to_json(&self) -> NFAResult<String> {
        serde_json::to_string_pretty(self)
            .map_err(|e| NFAError::Serialization(format!("Failed to serialize NFA to JSON: {}", e)))
    }

    /// Deserialize the NFA graph from JSON
    pub fn from_json(json: &str) -> NFAResult<Self> {
        serde_json::from_str(json).map_err(|e| {
            NFAError::Deserialization(format!("Failed to deserialize NFA from JSON: {}", e))
        })
    }

    /// Get the number of states in the NFA
    pub fn state_count(&self) -> usize {
        self.nodes.len()
    }

    /// Get the number of transitions in the NFA
    pub fn transition_count(&self) -> usize {
        self.nodes
            .iter()
            .map(|node| {
                node.byte_transitions
                    .values()
                    .map(|targets| targets.len())
                    .sum::<usize>()
            })
            .sum()
    }

    /// Check if the NFA is empty (no states)
    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty()
    }

    /// Get all bytes that can be consumed by this NFA
    pub fn alphabet(&self) -> BTreeSet<u8> {
        self.nodes
            .iter()
            .flat_map(|node| node.byte_transitions.keys())
            .copied()
            .collect()
    }

    /// Pretty print the NFA for debugging
    pub fn pretty_print(&self) {
        println!("\n=== Final NFA Graph ===");
        println!("Regex: {}", self.regex);
        println!("States: {}", self.state_count());
        println!("Transitions: {}", self.transition_count());
        println!("Capture Groups: {}", self.num_capture_groups);
        println!("Start states: {:?}", self.start_states);
        println!("Accept states: {:?}", self.accept_states);
        println!("\nState Details:");

        for (idx, node) in self.nodes.iter().enumerate() {
            println!("\nState {}: ", idx);

            if self.start_states.contains(&idx) {
                println!("  [START STATE]");
            }
            if self.accept_states.contains(&idx) {
                println!("  [ACCEPT STATE]");
            }

            // Print byte transitions
            if !node.byte_transitions.is_empty() {
                println!("  Byte transitions:");
                for (&byte, destinations) in &node.byte_transitions {
                    let char_repr = if byte.is_ascii_graphic() && byte != b' ' {
                        format!("'{}'", byte as char)
                    } else {
                        format!("0x{:02x}", byte)
                    };
                    println!("    {} -> {:?}", char_repr, destinations);
                }
            }

            // Print capture groups
            if !node.capture_groups.is_empty() {
                println!("  Capture groups:");
                for (target, captures) in &node.capture_groups {
                    for &(group_id, is_start) in captures {
                        println!(
                            "    -> state {}: group {} {}",
                            target,
                            group_id,
                            if is_start { "start" } else { "end" }
                        );
                    }
                }
            }

            if node.byte_transitions.is_empty() && node.capture_groups.is_empty() {
                println!("  [No transitions]");
            }
        }
        println!("\n=== End of Graph ===\n");
    }
}
