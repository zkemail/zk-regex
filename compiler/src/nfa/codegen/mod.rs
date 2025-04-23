//! Code generation module for converting NFAs to various output formats.

pub mod circom;
pub mod noir;

use regex_automata::meta::Regex;
use serde::Serialize;
use std::collections::HashMap;

use crate::nfa::{
    NFAGraph,
    error::{NFAError, NFAResult},
};

#[derive(Serialize)]
pub struct CircuitInputs {
    in_haystack: Vec<u8>,
    match_start: usize,
    match_length: usize,
    curr_states: Vec<usize>,
    next_states: Vec<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    capture_group_ids: Option<Vec<usize>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    capture_group_starts: Option<Vec<u8>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    capture_group_start_indices: Option<Vec<usize>>,
    traversal_path_length: usize,
}

impl NFAGraph {
    pub fn generate_circuit_data(
        &self,
    ) -> NFAResult<(
        Vec<usize>,
        Vec<usize>,
        Vec<(usize, u8, u8, usize, Option<(usize, bool)>)>,
    )> {
        if self.start_states.is_empty() {
            return Err(NFAError::Verification("NFA has no start states".into()));
        }
        if self.accept_states.is_empty() {
            return Err(NFAError::Verification("NFA has no accept states".into()));
        }

        let start_states = self.start_states.iter().copied().collect();
        let accept_states = self.accept_states.iter().copied().collect();

        let transitions = self.get_transitions_with_capture_info();
        if transitions.is_empty() {
            return Err(NFAError::Verification("NFA has no transitions".into()));
        }

        // Group and convert to ranges
        let mut range_transitions = Vec::new();
        let mut grouped: HashMap<(usize, usize, Option<(usize, bool)>), Vec<u8>> = HashMap::new();

        for (src, byte, dst, capture) in transitions {
            if src >= self.nodes.len() || dst >= self.nodes.len() {
                return Err(NFAError::InvalidStateId(format!(
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

    pub fn generate_circuit_inputs(
        &self,
        haystack: &str,
        max_haystack_len: usize,
        max_match_len: usize,
    ) -> NFAResult<CircuitInputs> {
        let haystack_bytes = haystack.as_bytes();

        if haystack_bytes.len() > max_haystack_len {
            return Err(NFAError::InvalidInput(format!(
                "Haystack length {} exceeds maximum length {}",
                haystack_bytes.len(),
                max_haystack_len
            )));
        }

        // Generate path traversal
        let result = self.get_path_to_accept(haystack_bytes)?;
        let path = result.path;
        let (match_start, match_length) = result.span;
        let path_len = path.len();

        if path_len > max_match_len {
            return Err(NFAError::InvalidInput(format!(
                "Path length {} exceeds maximum length {}",
                path_len, max_match_len
            )));
        }

        // Extract and pad arrays to max_haystack_len
        let mut curr_states = path.iter().map(|(curr, _, _, _)| *curr).collect::<Vec<_>>();
        let mut next_states = path.iter().map(|(_, next, _, _)| *next).collect::<Vec<_>>();
        let mut in_haystack = haystack_bytes.to_vec();

        // Pad with zeros
        curr_states.resize(max_match_len, 0);
        next_states.resize(max_match_len, 0);
        in_haystack.resize(max_haystack_len, 0);

        // Handle capture groups if they exist
        let (capture_group_ids, capture_group_starts, capture_group_start_indices) =
            if path.iter().any(|(_, _, _, c)| c.is_some()) {
                let mut ids = path
                    .iter()
                    .map(|(_, _, _, c)| c.map(|(id, _)| id).unwrap_or(0))
                    .collect::<Vec<_>>();
                let mut starts = path
                    .iter()
                    .map(|(_, _, _, c)| c.map(|(_, start)| start as u8).unwrap_or(0))
                    .collect::<Vec<_>>();

                // Use regex_automata to get capture start indices
                let re = Regex::new(&self.regex).map_err(|e| {
                    NFAError::RegexCompilation(format!("Failed to compile regex: {}", e))
                })?;
                let mut captures = re.create_captures();
                re.captures(&haystack, &mut captures);

                let start_indices = (1..=captures.group_len())
                    .filter_map(|i| captures.get_group(i))
                    .map(|m| m.start)
                    .collect();

                // Pad arrays
                ids.resize(max_match_len, 0);
                starts.resize(max_match_len, 0);

                (Some(ids), Some(starts), Some(start_indices))
            } else {
                (None, None, None)
            };

        Ok(CircuitInputs {
            in_haystack,
            match_start,
            match_length,
            curr_states,
            next_states,
            capture_group_ids,
            capture_group_starts,
            capture_group_start_indices,
            traversal_path_length: path_len,
        })
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
