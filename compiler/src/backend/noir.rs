use comptime::{FieldElement, SparseArray};
use heck::ToUpperCamelCase;
use serde::Serialize;
use std::collections::BTreeSet;

use super::{CircuitInputs, escape_regex_for_display, generate_circuit_data};
use crate::{
    ir::NFAGraph,
    passes::{NFAError, NFAResult},
};

#[derive(Serialize)]
pub struct NoirInputs {
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

// From implementation moved to shared.rs

/// Transition lookup keys are packed as `state + byte * 2^16 + next_state * 2^24` (see
/// `noir/src/utils/transitions.nr`). Bytes are `u8` and the circuit range-checks both states to
/// 16 bits, so the packing is injective as long as every state id of the automaton fits in 16
/// bits, which `ensure_states_fit_u16` enforces at compile time.
const NOIR_BYTE_SHIFT: usize = 1 << 16;
const NOIR_NEXT_STATE_SHIFT: usize = 1 << 24;
const NOIR_MAX_STATES: usize = 1 << 16;

fn transition_key(state: usize, byte: u8, next_state: usize) -> usize {
    state + byte as usize * NOIR_BYTE_SHIFT + next_state * NOIR_NEXT_STATE_SHIFT
}

/// Reject automata whose state ids do not fit in the 16 bits the generated circuit allows.
fn ensure_states_fit_u16(nfa: &NFAGraph) -> NFAResult<()> {
    if nfa.nodes.len() > NOIR_MAX_STATES {
        return Err(NFAError::TemplateError(format!(
            "Regex is too large for the Noir backend: the automaton has {} states, but Noir \
             circuits range-check state ids to 16 bits (at most {NOIR_MAX_STATES} states).",
            nfa.nodes.len()
        )));
    }
    Ok(())
}

/// Generate Noir code for the NFA
pub fn generate_noir_code(
    nfa: &NFAGraph,
    regex_name: &str,
    regex_pattern: &str,
    max_substring_bytes: Option<Vec<usize>>,
) -> NFAResult<String> {
    // get nfa graph data
    let (start_states, accept_states, transitions) = generate_circuit_data(nfa)?;

    ensure_states_fit_u16(nfa)?;

    if nfa.num_capture_groups > 0 {
        if let Some(max_bytes) = max_substring_bytes.as_ref() {
            if max_bytes.len() != nfa.num_capture_groups {
                return Err(NFAError::InvalidCapture(format!(
                    "Insufficient max_substring_bytes: need {} but got {}",
                    nfa.num_capture_groups,
                    max_bytes.len()
                )));
            }
            for &bytes in max_bytes {
                if bytes == 0 {
                    return Err(NFAError::InvalidCapture(
                        "max_substring_bytes contains zero length".into(),
                    ));
                }
            }
        } else {
            return Err(NFAError::InvalidCapture(
                "max_substring_bytes required for capture groups".into(),
            ));
        }
    }

    let mut code = String::new();

    // imports
    // todo: ability to change import path
    if nfa.num_capture_groups > 0 {
        code.push_str("use zkregex::utils::{\n");
        code.push_str("   select_subarray,\n");
        code.push_str("   captures::capture_substring,\n");
        code.push_str("   sparse_array::SparseArray,\n");
        code.push_str("   transitions::check_transition_with_captures\n");
        code.push_str("};\n\n");
    } else {
        code.push_str("use zkregex::utils::{\n");
        code.push_str("   select_subarray,\n");
        code.push_str("   sparse_array::SparseArray,\n");
        code.push_str("   transitions::check_transition\n");
        code.push_str("};\n\n");
    }

    // codegen the transition lookup table
    let transition_array = match max_substring_bytes.as_ref().is_some() {
        true => packed_transition_sparse_array(&transitions, nfa.num_capture_groups),
        false => transition_sparse_array(&transitions),
    };
    code.push_str(&format!(
        "global TRANSITION_TABLE: {}\n\n",
        transition_array.to_noir_string(None)
    ));

    // hardcode max substring capture group lengths
    if nfa.num_capture_groups > 0 {
        for (index, length) in max_substring_bytes.as_ref().unwrap().iter().enumerate() {
            code.push_str(&format!(
                "pub global CAPTURE_{}_MAX_LENGTH: u32 = {};\n",
                index + 1,
                length
            ));
        }
        code.push_str(&format!(
            "pub global NUM_CAPTURE_GROUPS: u32 = {};\n",
            nfa.num_capture_groups
        ));
    }

    let display_pattern = escape_regex_for_display(regex_pattern);

    // add check for valid start states
    code.push_str(start_state_fn(&start_states).as_str());
    let anchored_start_states: Vec<usize> = nfa.anchored_start_states.iter().copied().collect();
    if !anchored_start_states.is_empty() {
        code.push_str(start_anchor_fn(&anchored_start_states).as_str());
    }
    code.push_str(accept_state_fn(&accept_states).as_str());

    // regex match function doc
    code.push_str("/**\n");
    code.push_str(&format!(
        " * {}Regex matching function\n",
        regex_name.to_upper_camel_case()
    ));
    code.push_str(&format!(" * Regex: {display_pattern}\n"));
    code.push_str(" * @param in_haystack - The input haystack to search from\n");
    code.push_str(" * @param match_start - The start index in the haystack for the subarray to match from\n");
    code.push_str(" * @param match_length - The length of the subarray to extract from haystack\n");
    code.push_str(
        " * @param current_states - The current states of the NFA at each index in the match subarray\n"
    );
    code.push_str(" * @param next_states - The next states of the NFA at each index in the match subarray\n");
    if nfa.num_capture_groups > 0 {
        code.push_str(
            " * @param capture_group_<group>_ids - The ids of the capture groups in the match subarray\n"
        );
        code.push_str(
            " * @param capture_group_<group>_starts - The start positions of the capture groups in the match subarray\n"
        );
        code.push_str(
            " * @param capture_group_start_indices - The start indices of the capture groups in the match subarray\n"
        );
        code.push_str(" * @return - tuple of substring captures as dictated by the regular expression\n");
    }
    code.push_str(" */\n");

    code.push_str("pub fn regex_match<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(\n");
    code.push_str("    in_haystack: [u8; MAX_HAYSTACK_LEN],\n");
    code.push_str("    match_start: u32,\n");
    code.push_str("    match_length: u32,\n");
    code.push_str("    current_states: [Field; MAX_MATCH_LEN],\n");
    code.push_str("    next_states: [Field; MAX_MATCH_LEN],\n");
    if nfa.num_capture_groups > 0 {
        for i in 1..=nfa.num_capture_groups {
            code.push_str(&format!(
                "    capture_group_{i}_id: [Field; MAX_MATCH_LEN],\n"
            ));
        }
        for i in 1..=nfa.num_capture_groups {
            code.push_str(&format!(
                "    capture_group_{i}_start: [Field; MAX_MATCH_LEN],\n"
            ));
        }
        code.push_str("    capture_group_start_indices: [Field; NUM_CAPTURE_GROUPS],\n");
    }

    // define the return type according to existence of / qualities of capture groups
    let return_type = if nfa.num_capture_groups > 0 {
        let mut substrings = Vec::new();
        for i in 1..=nfa.num_capture_groups {
            substrings.push(format!("BoundedVec<u8, CAPTURE_{i}_MAX_LENGTH>"));
        }
        format!("-> ({}) ", substrings.join(", "))
    } else {
        String::default()
    };
    code.push_str(&format!(") {return_type}{{\n"));

    // resize haystack to MAX_MATCH_LEN
    code.push_str("    // resize haystack \n");
    code.push_str(
        "    let haystack: [u8; MAX_MATCH_LEN] = select_subarray::<MAX_HAYSTACK_LEN, MAX_MATCH_LEN>(in_haystack, match_start, match_length);\n\n"
    );

    // check start & range
    code.push_str("    check_start_state(current_states[0]);\n");
    if !anchored_start_states.is_empty() {
        code.push_str("    check_start_anchor(current_states[0], match_start);\n");
    }
    code.push_str("    for i in 0..MAX_MATCH_LEN-1 {\n");
    code.push_str("        // match length - 1 since current states should be 1 less than next states\n");
    code.push_str("        let in_range = (i < match_length - 1) as Field;\n");
    code.push_str("        let matching_states = current_states[i + 1] - next_states[i];\n");
    code.push_str("        assert(in_range * matching_states == 0, \"Invalid Transition Input\");\n");
    code.push_str("    }\n");

    // iterate through the haystack and check transitions
    code.push_str("    let mut reached_end_state = 1;\n");
    code.push_str("    for i in 0..MAX_MATCH_LEN {\n");
    if nfa.num_capture_groups > 0 {
        let active_ids_str = (1..=nfa.num_capture_groups)
            .map(|i| format!("capture_group_{i}_id[i]"))
            .collect::<Vec<String>>()
            .join(", ");
        let active_starts_str = (1..=nfa.num_capture_groups)
            .map(|i| format!("capture_group_{i}_start[i]"))
            .collect::<Vec<String>>()
            .join(", ");

        code.push_str(&format!(
            "        let active_capture_groups_at_index = [{active_ids_str}];\n"
        ));
        code.push_str(&format!(
            "        let active_capture_groups_starts_at_index = [{active_starts_str}];\n"
        ));

        // if capture groups exist, perform check that unpacks transition values
        code.push_str("        check_transition_with_captures(\n");
        code.push_str("            TRANSITION_TABLE,\n");
        code.push_str("            haystack[i] as Field,\n");
        code.push_str("            current_states[i],\n");
        code.push_str("            next_states[i],\n");
        code.push_str("            active_capture_groups_at_index,\n");
        code.push_str("            active_capture_groups_starts_at_index,\n");
        code.push_str("            reached_end_state\n");
        code.push_str("        );\n");
    } else {
        // if no capture groups exist, simple lookup
        code.push_str("        check_transition(\n");
        code.push_str("            TRANSITION_TABLE,\n");
        code.push_str("            haystack[i] as Field,\n");
        code.push_str("            current_states[i],\n");
        code.push_str("            next_states[i],\n");
        code.push_str("            reached_end_state\n");
        code.push_str("        );\n");
    }

    // toggle off constraints/ set match assertion if end state found
    code.push_str(
        "        reached_end_state = reached_end_state * check_accept_state(next_states[i], i as Field, match_length as Field);\n"
    );
    code.push_str("    }\n");
    code.push_str("    assert(reached_end_state == 0, \"Did not reach a valid end state\");\n\n");

    // add substring capture logic if capture groups exist
    if nfa.num_capture_groups > 0 {
        let mut ids = Vec::new();
        for i in 1..=nfa.num_capture_groups {
            code.push_str(&format!("    // Capture Group {i}\n"));
            code.push_str(
                &format!(
                    "    let capture_{i} = capture_substring::<MAX_MATCH_LEN, CAPTURE_{i}_MAX_LENGTH, {i}>(\n"
                )
            );
            code.push_str("       haystack,\n");
            code.push_str(&format!("       capture_group_{i}_id,\n"));
            code.push_str(&format!("       capture_group_{i}_start,\n"));
            code.push_str(&format!("       capture_group_start_indices[{}]\n", i - 1));
            code.push_str("    );\n\n");
            ids.push(format!("capture_{i}"));
        }

        // define the return tuple
        let return_vec = ids
            .iter()
            .map(|id| id.to_string())
            .collect::<Vec<_>>()
            .join(", ");
        code.push_str(&format!("    ({return_vec})\n"));
    }

    code.push_str("}\n\n");

    Ok(code)
}

/// Generate Prover.toml from circuit inputs
pub fn to_prover_toml(inputs: &CircuitInputs) -> String {
    let mut toml = String::new();

    // regex match inputs
    let haystack = inputs
        .in_haystack
        .iter()
        .map(|num| format!("\"{num}\""))
        .collect::<Vec<_>>()
        .join(", ");

    toml.push_str(&format!("in_haystack = [{haystack}]\n"));
    toml.push_str(&format!("match_start = \"{}\"\n", inputs.match_start));
    toml.push_str(&format!("match_length = \"{}\"\n", inputs.match_length));

    let curr_states = inputs
        .curr_states
        .iter()
        .map(|num| format!("\"{num}\""))
        .collect::<Vec<_>>()
        .join(", ");
    toml.push_str(&format!("curr_states = [{curr_states}]\n"));

    let next_states = inputs
        .next_states
        .iter()
        .map(|num| format!("\"{num}\""))
        .collect::<Vec<_>>()
        .join(", ");
    toml.push_str(&format!("next_states = [{next_states}]\n"));

    // substring capture inputs
    if let Some(outer_ids_vec) = inputs.capture_group_ids.as_ref() {
        let outer_starts_vec = inputs
            .capture_group_starts
            .as_ref()
            .expect("capture_group_starts should be Some if capture_group_ids is Some");
        for i in 0..outer_ids_vec.len() {
            // Handle capture_group_{i+1}_ids
            let ids_for_group = &outer_ids_vec[i];
            let ids_str = ids_for_group
                .iter()
                .map(|num| format!("\"{num}\""))
                .collect::<Vec<_>>()
                .join(", ");
            toml.push_str(&format!("capture_group_{}_ids = [{}]\n", i + 1, ids_str));

            // Handle capture_group_{i+1}_starts
            let starts_for_group = &outer_starts_vec[i];
            let starts_str = starts_for_group
                .iter()
                .map(|num| format!("\"{num}\""))
                .collect::<Vec<_>>()
                .join(", ");
            toml.push_str(&format!(
                "capture_group_{}_starts = [{}]\n",
                i + 1,
                starts_str
            ));
        }
    }

    // Handle capture_group_start_indices (Option<Vec<usize>>) - This is a flat list
    if let Some(start_indices_vec) = inputs.capture_group_start_indices.as_ref() {
        let capture_group_start_indices_str = start_indices_vec
            .iter()
            .map(|num| format!("\"{num}\""))
            .collect::<Vec<_>>()
            .join(", ");
        toml.push_str(&format!(
            "capture_group_start_indices = [{capture_group_start_indices_str}]\n"
        ));
    }
    toml
}

/**
 * Forms an expression to determine if any of the start states are matched
 * @param start_states - The start states of the NFA
 * @returns The expression determining if any of the start states are matched
 */
fn start_state_fn(start_states: &Vec<usize>) -> String {
    let expression = start_states
        .iter()
        .map(|state| format!("(start_state - {state})"))
        .collect::<Vec<String>>()
        .join(" * ");
    format!(
        r#"
/**
 * Constrains a start state to be valid
 * @dev start states are hardcoded in this function - "(start_state - {{state}})" for each start
 *      example: `(start_state - 0) * (start_state - 1) * (start_state - 2)` means 0, 1, or 2
 *      are valid first states
 * 
 * @param start_state - The start state of the NFA
 */
fn check_start_state(start_state: Field) {{
    let valid_start_state = {expression};
    assert(valid_start_state == 0, "Invalid start state");
}}
    "#
    )
}

/**
 * Forms the check that paths beginning in an anchored start state begin at haystack offset 0
 * @param anchored_start_states - The start states reached through a start anchor (`^`)
 * @returns The function constraining anchored start states to match_start == 0
 */
fn start_anchor_fn(anchored_start_states: &Vec<usize>) -> String {
    let expression = anchored_start_states
        .iter()
        .map(|state| format!("(start_state == {state})"))
        .collect::<Vec<String>>()
        .join(" | ");
    format!(
        r#"
/**
 * Constrains paths that begin in an anchored start state to begin at the start of the haystack
 * @dev anchored start states are hardcoded in this function. They are entered by crossing a
 *      start anchor (`^`), which only holds at haystack offset 0.
 *
 * @param start_state - The start state of the NFA
 * @param match_start - The start index of the match in the haystack
 */
fn check_start_anchor(start_state: Field, match_start: u32) {{
    let is_anchored_start = {expression};
    assert(!is_anchored_start | (match_start == 0), "Start anchor requires match_start == 0");
}}
"#
    )
}

/**
 * Forms an expression to determine if any of the accept states are matched
 * @param start_states - The accept states of the NFA
 * @returns The expression determining if any of the accept states are matched
 */
fn accept_state_fn(accept_states: &Vec<usize>) -> String {
    let expression = accept_states
        .iter()
        .map(|state| format!("(next_state - {state})"))
        .collect::<Vec<String>>()
        .join(" * ");
    format!(
        r#"
/**
 * Constrains the recognition of accept_state being reached. If an aceppt state is reached,
 *      ensures asserted traversal path is valid
 * @dev accept states are hardcoded in this function - "(next_state - {{state}})" for each accept
 *      example: `(next_state - 19) * (next_state - 20) * (next_state - 21)` means 19, 20, or 21
 *      are valid accept states
 * 
 * @param next_state - The asserted next state of the NFA
 * @param haystack_index - The index being operated on in the haystack
 * @param asserted_match_length - The asserted traversal path length
 * @return - 0 if accept_state is reached, nonzero otherwise
 */
fn check_accept_state(
    next_state: Field,
    haystack_index: Field, 
    asserted_match_length: Field
) -> Field {{
    // check if the next state is an accept state
    let accept_state_reached = {expression};
    let accept_state_reached_bool = (accept_state_reached == 0) as Field;

    // check if the haystack index is the asserted match length
    // should equal 1 since haystack_index should be 1 less than asserted_match)length
    let asserted_path_traversed = (asserted_match_length - haystack_index == 1) as Field;

    (1 - (accept_state_reached_bool * asserted_path_traversed))
}}

"#
    )
}

/**
 * Creates a sparse array for transitions
 * @param transitions - The transitions to create the sparse array for
 * @returns The sparse array for the transitions
 */
fn transition_sparse_array(
    transitions: &Vec<(usize, u8, u8, usize, Option<BTreeSet<(usize, bool)>>)>,
) -> SparseArray<FieldElement> {
    let mut entries = Vec::new();
    let mut max_key = 0;
    for (state_idx, start, end, dest, _) in transitions {
        for byte in *start..=*end {
            let key = transition_key(*state_idx, byte, *dest);
            max_key = max_key.max(key);
            entries.push(FieldElement::from(key));
        }
    }
    let values = vec![FieldElement::from(1u32); entries.len()];
    SparseArray::create(&entries, &values, FieldElement::from(max_key + 1))
}

/**
 * Creates a packed sparse array for transitions.
 * The packed 'value' encodes:
 * - Bit 0: 1 if this entry represents a valid transition.
 * - Bits 1 to N: 'starts_flags'. Bit k (1-indexed in this range) is 1 if capture group k starts here.
 * - Bits (N+1) to 2N: 'participations_flags'. Bit (k+N) (1-indexed in this range) is 1 if capture group k is involved.
 * (where N = num_capture_groups)
 */
fn packed_transition_sparse_array(
    transitions: &Vec<(usize, u8, u8, usize, Option<BTreeSet<(usize, bool)>>)>,
    num_capture_groups: usize,
) -> SparseArray<FieldElement> {
    let mut keys = Vec::new();
    let mut values = Vec::new();
    let mut max_key = 0;

    for (state_idx, start_byte, end_byte, dest_state, capture_opt) in transitions {
        let mut participations_flags = 0u32;
        let mut starts_flags = 0u32;

        if let Some(captures) = capture_opt {
            for (group_id, is_start) in captures {
                // Ensure group_id is 1-indexed and within bounds
                if *group_id > 0 && *group_id <= num_capture_groups {
                    participations_flags |= 1u32 << (*group_id - 1); // Set bit for participation
                    if *is_start {
                        starts_flags |= 1u32 << (*group_id - 1); // Set bit for start
                    }
                }
            }
        }

        // Pack the flags:
        // Bit 0: is_valid_transition (always 1 for these entries)
        // Next num_capture_groups bits: starts_flags
        // Next num_capture_groups bits: participations_flags
        let packed_value =
            1u32 | (starts_flags << 1) | (participations_flags << (1 + num_capture_groups));

        for byte_val in *start_byte..=*end_byte {
            let key = transition_key(*state_idx, byte_val, *dest_state);
            max_key = max_key.max(key);
            keys.push(FieldElement::from(key));
            values.push(FieldElement::from(packed_value));
        }
    }

    SparseArray::create(&keys, &values, FieldElement::from(max_key + 1))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_automata_past_the_old_257_state_limit() {
        // Unicode \w alone needs over 300 states.
        let nfa = NFAGraph::build(r"\w+").expect("pattern should compile to an NFA");
        assert!(nfa.state_count() > 257);
        let code = generate_noir_code(&nfa, "Word", r"\w+", None).expect("16-bit states fit");
        assert!(code.contains("transitions::check_transition"));
    }

    #[test]
    fn rejects_automata_with_more_than_2_16_states() {
        let mut nfa = NFAGraph::build("a").expect("pattern should compile to an NFA");
        nfa.nodes.resize(NOIR_MAX_STATES + 1, Default::default());
        let err = ensure_states_fit_u16(&nfa).expect_err("oversized automaton must be rejected");
        assert!(matches!(err, NFAError::TemplateError(_)), "got {err:?}");
    }

    #[test]
    fn transition_keys_are_injective_for_16_bit_states() {
        let corners = [0, 1, 255, 256, 257, NOIR_MAX_STATES - 1];
        let mut seen = std::collections::BTreeMap::new();
        for &s in &corners {
            for b in [0u8, 1, 127, 255] {
                for &t in &corners {
                    assert_eq!(seen.insert(transition_key(s, b, t), (s, b, t)), None);
                }
            }
        }
        assert!(transition_key(NOIR_MAX_STATES - 1, 255, NOIR_MAX_STATES - 1) < 1 << 40);
    }

    #[test]
    fn anchored_start_states_require_match_start_zero() {
        let nfa = NFAGraph::build("(?:\r\n|^)from:").expect("pattern should compile");
        let anchored = *nfa.anchored_start_states.first().expect("one anchored start state");
        let code = generate_noir_code(&nfa, "From", "(?:\r\n|^)from:", None).unwrap();

        assert!(code.contains(&format!("let is_anchored_start = (start_state == {anchored});")));
        assert!(code.contains("check_start_anchor(current_states[0], match_start);"));

        let nfa = NFAGraph::build("(?:\r\n|x)from:").expect("pattern should compile");
        let code = generate_noir_code(&nfa, "From", "(?:\r\n|x)from:", None).unwrap();
        assert!(!code.contains("check_start_anchor"));
    }

    #[test]
    fn accepts_automata_within_key_encoding() {
        let nfa = NFAGraph::build("a{10}b+").expect("pattern should compile to an NFA");
        generate_noir_code(&nfa, "Small", "a{10}b+", None).expect("small automaton is fine");
    }
}
