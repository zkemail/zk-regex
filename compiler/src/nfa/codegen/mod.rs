mod circom;
mod noir;

use std::collections::HashMap;

use crate::nfa::{
    NFAGraph,
    error::{NFABuildError, NFAResult},
};

impl NFAGraph {
    pub fn generate_circuit_data(
        &self,
    ) -> NFAResult<(
        Vec<usize>,
        Vec<usize>,
        Vec<(usize, u8, u8, usize, Option<(usize, bool)>)>,
    )> {
        if self.start_states.is_empty() {
            return Err(NFABuildError::Verification(
                "NFA has no start states".into(),
            ));
        }
        if self.accept_states.is_empty() {
            return Err(NFABuildError::Verification(
                "NFA has no accept states".into(),
            ));
        }

        let start_states = self.start_states.iter().copied().collect();
        let accept_states = self.accept_states.iter().copied().collect();

        let transitions = self.get_transitions_with_capture_info();
        if transitions.is_empty() {
            return Err(NFABuildError::Verification("NFA has no transitions".into()));
        }

        // Group and convert to ranges
        let mut range_transitions = Vec::new();
        let mut grouped: HashMap<(usize, usize, Option<(usize, bool)>), Vec<u8>> = HashMap::new();

        for (src, byte, dst, capture) in transitions {
            if src >= self.nodes.len() || dst >= self.nodes.len() {
                return Err(NFABuildError::InvalidStateId(format!(
                    "State {}->{} out of bounds",
                    src, dst
                )));
            }
            grouped.entry((src, dst, capture)).or_default().push(byte);
        }

        // Convert to ranges
        for ((src, dst, capture), mut bytes) in grouped {
            if bytes.is_empty() {
                continue;
            }

            bytes.sort_unstable();
            let mut start = bytes[0];
            let mut prev = start;

            for &byte in &bytes[1..] {
                if byte != prev + 1 {
                    range_transitions.push((src, start, prev, dst, capture));
                    start = byte;
                }
                prev = byte;
            }
            range_transitions.push((src, start, prev, dst, capture));
        }

        Ok((start_states, accept_states, range_transitions))
    }

    pub fn escape_regex_for_display(pattern: &str) -> String {
        pattern
            .chars()
            .map(|c| match c {
                '\n' => "\\n".to_string(),
                '\r' => "\\r".to_string(),
                '\t' => "\\t".to_string(),
                '\\' => "\\\\".to_string(),
                '\0' => "\\0".to_string(),
                '\'' => "\\'".to_string(),
                '\"' => "\\\"".to_string(),
                '\x08' => "\\b".to_string(),
                '\x0c' => "\\f".to_string(),
                c if c.is_ascii_control() => format!("\\x{:02x}", c as u8),
                c => c.to_string(),
            })
            .collect()
    }
}
