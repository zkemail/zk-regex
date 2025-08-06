//! Shared functions for code generation backends

use regex_automata::meta::Regex;
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};

use crate::{
    ProverInputs, ProvingFramework,
    ir::NFAGraph,
    passes::{NFAError, NFAResult},
};

// Import the specific input types
use super::circom::CircomInputs;
use super::noir::NoirInputs;

#[derive(Serialize)]
pub struct CircuitInputs {
    pub in_haystack: Vec<u8>,
    pub match_start: usize,
    pub match_length: usize,
    pub curr_states: Vec<usize>,
    pub next_states: Vec<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub capture_group_ids: Option<Vec<Vec<usize>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub capture_group_starts: Option<Vec<Vec<u8>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub capture_group_start_indices: Option<Vec<usize>>,
}

impl From<CircuitInputs> for CircomInputs {
    fn from(inputs: CircuitInputs) -> Self {
        CircomInputs {
            in_haystack: inputs.in_haystack,
            match_start: inputs.match_start,
            match_length: inputs.match_length,
            curr_states: inputs.curr_states,
            next_states: inputs.next_states,
            capture_group_ids: inputs.capture_group_ids,
            capture_group_starts: inputs.capture_group_starts,
            capture_group_start_indices: inputs.capture_group_start_indices,
        }
    }
}

impl From<CircuitInputs> for NoirInputs {
    fn from(inputs: CircuitInputs) -> Self {
        NoirInputs {
            in_haystack: inputs.in_haystack,
            match_start: inputs.match_start,
            match_length: inputs.match_length,
            curr_states: inputs.curr_states,
            next_states: inputs.next_states,
            capture_group_ids: inputs.capture_group_ids,
            capture_group_starts: inputs.capture_group_starts,
            capture_group_start_indices: inputs.capture_group_start_indices,
        }
    }
}

pub fn generate_circuit_data(
    nfa: &NFAGraph,
) -> NFAResult<(
    Vec<usize>,
    Vec<usize>,
    Vec<(usize, u8, u8, usize, Option<BTreeSet<(usize, bool)>>)>,
)> {
    if nfa.start_states.is_empty() {
        return Err(NFAError::Verification("NFA has no start states".into()));
    }
    if nfa.accept_states.is_empty() {
        return Err(NFAError::Verification("NFA has no accept states".into()));
    }

    // Use sorted collections for deterministic ordering
    let mut start_states: Vec<_> = nfa.start_states.iter().copied().collect();
    start_states.sort_unstable();

    let mut accept_states: Vec<_> = nfa.accept_states.iter().copied().collect();
    accept_states.sort_unstable();

    let transitions = nfa.get_transitions_with_capture_info();
    if transitions.is_empty() {
        return Err(NFAError::Verification("NFA has no transitions".into()));
    }

    // Group and convert to ranges - use BTreeMap for deterministic ordering
    let mut range_transitions = Vec::new();
    let mut grouped: BTreeMap<(usize, usize, Option<BTreeSet<(usize, bool)>>), Vec<u8>> =
        BTreeMap::new();

    for (src, byte, dst, capture) in transitions {
        if src >= nfa.nodes.len() || dst >= nfa.nodes.len() {
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
            return Err(NFAError::InvalidTransition(format!(
                "Found an empty byte list for transition group (src: {}, dst: {}, capture: {:?})",
                src, dst, capture
            )));
        }

        bytes.sort_unstable();
        let mut start = bytes[0];
        let mut prev = start;

        for &byte in &bytes[1..] {
            if byte != prev + 1 {
                range_transitions.push((src, start, prev, dst, capture.clone()));
                start = byte;
            }
            prev = byte;
        }
        range_transitions.push((src, start, prev, dst, capture.clone()));
    }

    Ok((start_states, accept_states, range_transitions))
}

pub fn generate_circuit_inputs(
    nfa: &NFAGraph,
    haystack: &str,
    max_haystack_len: usize,
    max_match_len: usize,
    proving_framework: ProvingFramework,
) -> NFAResult<ProverInputs> {
    let haystack_bytes = haystack.as_bytes();

    if haystack_bytes.len() > max_haystack_len {
        return Err(NFAError::InvalidInput(format!(
            "Haystack length {} exceeds maximum length {}",
            haystack_bytes.len(),
            max_haystack_len
        )));
    }

    // Generate path traversal
    let result = nfa.get_path_to_accept(haystack_bytes)?;
    let path = result.path;
    let (match_start, match_length) = result.span;
    let path_len = path.len();

    if path_len != match_length {
        return Err(NFAError::InvalidInput(format!(
            "Path length {} does not equal match length {}",
            path_len, match_length
        )));
    }

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
            let mut capture_group_ids: Vec<Vec<usize>> =
                vec![vec![0; max_match_len]; nfa.num_capture_groups];
            let mut capture_group_starts: Vec<Vec<u8>> =
                vec![vec![0; max_match_len]; nfa.num_capture_groups];

            for step_idx in 0..path_len {
                if let Some(capture_set) = &path[step_idx].3 {
                    for (group_id, is_start) in capture_set.iter() {
                        if *group_id > 0 && *group_id <= nfa.num_capture_groups {
                            let group_vector_idx = *group_id - 1;
                            capture_group_ids[group_vector_idx][step_idx] = *group_id;
                            capture_group_starts[group_vector_idx][step_idx] =
                                if *is_start { 1 } else { 0 };
                        }
                    }
                }
            }

            let re = Regex::new(&nfa.regex).map_err(|e| {
                NFAError::RegexCompilation(format!("Failed to compile regex: {}", e))
            })?;
            let mut captures = re.create_captures();
            re.captures(&haystack, &mut captures);

            let start_indices = (1..=captures.group_len())
                .filter_map(|i| captures.get_group(i))
                .map(|m| m.start - match_start)
                .collect();

            (
                Some(capture_group_ids),
                Some(capture_group_starts),
                Some(start_indices),
            )
        } else {
            (None, None, None)
        };

    let inputs = CircuitInputs {
        in_haystack,
        match_start,
        match_length,
        curr_states,
        next_states,
        capture_group_ids,
        capture_group_starts,
        capture_group_start_indices,
    };

    match proving_framework {
        ProvingFramework::Circom => Ok(ProverInputs::Circom(inputs.into())),
        ProvingFramework::Noir => Ok(ProverInputs::Noir(inputs.into())),
    }
}

pub fn escape_regex_for_display(pattern: &str) -> String {
    pattern
        .chars()
        .map(|c| match c {
            '\\' => "\\\\".to_string(),
            '"' => "\\\"".to_string(),
            '\n' => "\\n".to_string(),
            '\r' => "\\r".to_string(),
            '\t' => "\\t".to_string(),
            c if c.is_control() => format!("\\x{:02x}", c as u8),
            c => c.to_string(),
        })
        .collect()
}
