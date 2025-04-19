use std::collections::{HashMap, HashSet};

use crate::nfa::{
    NFAGraph,
    codegen::CircuitInputs,
    error::{NFABuildError, NFAResult},
};
use comptime::{FieldElement, SparseArray};

impl NFAGraph {
    /// Generate Circom code for the NFA
    pub fn generate_noir_code(
        &self,
        regex_name: &str,
        regex_pattern: &str,
        max_substring_bytes: Option<&[usize]>,
    ) -> NFAResult<String> {
        // get nfa graph data
        let (start_states, accept_states, transitions) = self.generate_circuit_data()?;

        // build sparse array
        let transition_array = match max_substring_bytes.is_some() {
            true => packed_transition_sparse_array(&transitions),
            false => transition_sparse_array(&transitions),
        };

        let capture_group_set: HashSet<_> = transitions
            .iter()
            .filter_map(|(_, _, _, _, cap)| cap.map(|(id, _)| id))
            .collect();
        if !capture_group_set.is_empty() {
            if let Some(max_bytes) = max_substring_bytes {
                if max_bytes.len() < capture_group_set.len() {
                    return Err(NFABuildError::InvalidCapture(format!(
                        "Insufficient max_substring_bytes: need {} but got {}",
                        capture_group_set.len(),
                        max_bytes.len()
                    )));
                }
                for &bytes in max_bytes {
                    if bytes == 0 {
                        return Err(NFABuildError::InvalidCapture(
                            "max_substring_bytes contains zero length".into(),
                        ));
                    }
                }
            } else {
                return Err(NFABuildError::InvalidCapture(
                    "max_substring_bytes required for capture groups".into(),
                ));
            }
        }

        let has_capture_groups = !capture_group_set.is_empty();

        let mut code = String::new();

        // imports
        // todo: ability to change import path
        if has_capture_groups {
            code.push_str("use crate::common::{capture_substring, check_transition_with_captures, SparseArray};\n\n");
        } else {
            code.push_str("use crate::common::{check_transition, SparseArray};\n\n");
        }

        // codegen consts
        code.push_str(&format!(
            "global TRANSITION_TABLE: {}\n\n",
            transition_array.to_noir_string(None)
        ));

        // hardcode max substring capture group lengths
        if has_capture_groups {
            for (index, length) in max_substring_bytes.unwrap().iter().enumerate() {
                code.push_str(&format!(
                    "pub global CAPTURE_{}_MAX_LENGTH: u32 = {};\n",
                    index + 1,
                    length
                ));
            }
            code.push_str(&format!(
                "pub global NUM_CAPTURE_GROUPS: u32 = {};\n",
                capture_group_set.len()
            ));
        }

        // add check for valid start states
        code.push_str(start_state_fn(&start_states).as_str());
        code.push_str(accept_state_fn(&accept_states).as_str());

        // regex match fn
        code.push_str(&format!(
            "pub fn regex_match<let MAX_HAYSTACK_LENTH: u32>(\n"
        ));
        code.push_str(&format!("    haystack: [u8; MAX_HAYSTACK_LENTH],\n"));
        code.push_str(&format!(
            "    current_states: [Field; MAX_HAYSTACK_LENTH],\n"
        ));
        code.push_str(&format!("    next_states: [Field; MAX_HAYSTACK_LENTH],\n"));
        code.push_str(&format!("    transition_length: u32,\n"));
        if (max_substring_bytes.is_some()) {
            code.push_str(&format!("    capture_ids: [Field; MAX_HAYSTACK_LENTH],\n"));
            code.push_str(&format!(
                "    capture_starts: [Field; MAX_HAYSTACK_LENTH],\n"
            ));
            code.push_str(&format!(
                "    capture_start_indices: [Field; NUM_CAPTURE_GROUPS],\n"
            ));
        }
        let return_type = if has_capture_groups {
            let mut substrings = Vec::new();
            for i in 0..max_substring_bytes.unwrap().len() {
                substrings.push(format!("BoundedVec<u8, CAPTURE_{}_MAX_LENGTH>", i + 1));
            }
            format!("-> ({}) ", substrings.join(", "))
        } else {
            String::default()
        };
        code.push_str(&format!(") {}{{\n", return_type));
        code.push_str(&format!("    // regex:{:?}\n", regex_pattern));
        code.push_str(&format!("    let mut reached_end_state = 1;\n"));
        code.push_str(&format!("    check_start_state(current_states[0]);\n"));
        code.push_str(&format!("    for i in 0..MAX_HAYSTACK_LENTH-1 {{\n"));
        code.push_str(&format!("        // transition length - 1 since current states should be 1 less than next states\n"));
        code.push_str(&format!(
            "        let in_range = (i < transition_length - 1) as Field;\n"
        ));
        code.push_str(&format!(
            "        let matching_states = current_states[i + 1] - next_states[i];\n"
        ));
        code.push_str(&format!(
            "        assert(in_range * matching_states == 0, \"Invalid Transition Input\");\n"
        ));
        code.push_str(&format!("    }}\n"));
        code.push_str(&format!("    for i in 0..MAX_HAYSTACK_LENTH {{\n"));
        if max_substring_bytes.is_some() {
            code.push_str(&format!("        check_transition_with_captures(\n"));
            code.push_str(&format!("            haystack[i] as Field,\n"));
            code.push_str(&format!("            current_states[i],\n"));
            code.push_str(&format!("            next_states[i],\n"));
            code.push_str(&format!("            capture_ids[i],\n"));
            code.push_str(&format!("            capture_starts[i],\n"));
            code.push_str(&format!("            reached_end_state,\n"));
            code.push_str(&format!("            TRANSITION_TABLE\n"));
            code.push_str(&format!("        );\n"));
        } else {
            code.push_str(&format!("        check_transition(\n"));
            code.push_str(&format!("            haystack[i] as Field,\n"));
            code.push_str(&format!("            current_states[i],\n"));
            code.push_str(&format!("            next_states[i],\n"));
            code.push_str(&format!("            reached_end_state,\n"));
            code.push_str(&format!("            TRANSITION_TABLE\n"));
            code.push_str(&format!("        );\n"));
        }
        code.push_str(&format!("        reached_end_state = reached_end_state * check_accept_state(\n"));
        code.push_str(&format!("            next_states[i],\n"));
        code.push_str(&format!("            i as Field,\n"));
        code.push_str(&format!("            transition_length as Field,\n"));
        code.push_str(&format!("        );\n"));
        code.push_str(&format!("    }}\n"));
        code.push_str(&format!(
            "    assert(reached_end_state == 0, \"Did not reach a valid end state\");\n"
        ));
        if has_capture_groups {
            let mut ids = Vec::new();
            for capture_group_id in capture_group_set {
                let max_substring_bytes = if let Some(max_substring_bytes) = max_substring_bytes {
                    max_substring_bytes[capture_group_id - 1]
                } else {
                    return Err(NFABuildError::InvalidCapture(format!(
                        "Max substring bytes not provided for capture group {}",
                        capture_group_id
                    )));
                };

                code.push_str(&format!("     // Capture Group {}\n", capture_group_id));
                code.push_str(&format!("     let capture_{} = capture_substring::<MAX_HAYSTACK_LENTH, CAPTURE_{}_MAX_LENGTH, {}>(\n", capture_group_id, capture_group_id, capture_group_id));
                code.push_str(&format!("        haystack,\n"));
                code.push_str(&format!("        capture_ids,\n"));
                code.push_str(&format!("        capture_starts,\n"));
                code.push_str(&format!(
                    "        capture_start_indices[{}],\n",
                    capture_group_id - 1
                ));
                code.push_str(&format!("     );\n"));
                ids.push(format!("capture_{}", capture_group_id));
            }
            let return_vec = ids
                .iter()
                .map(|id| format!("{}", id))
                .collect::<Vec<_>>()
                .join(", ");
            code.push_str(&format!("    ({})\n", return_vec));
        }
        code.push_str(&format!("}}\n\n"));
        Ok(code)
    }

    pub fn to_prover_toml(inputs: &CircuitInputs) -> String {
        let mut toml = String::new();

        // regex match inputs
        let haystack = inputs
            .in_haystack
            .iter()
            .map(|num| format!("\"{num}\""))
            .collect::<Vec<_>>()
            .join(", ");
        toml.push_str(&format!("haystack = [{}]\n", haystack));
        let curr_states = inputs
            .curr_states
            .iter()
            .map(|num| format!("\"{num}\""))
            .collect::<Vec<_>>()
            .join(", ");
        toml.push_str(&format!("curr_states = [{}]\n", curr_states));
        let next_states = inputs
            .next_states
            .iter()
            .map(|num| format!("\"{num}\""))
            .collect::<Vec<_>>()
            .join(", ");
        toml.push_str(&format!("next_states = [{}]\n", next_states));
        toml.push_str(&format!(
            "traversal_path_length = \"{}\"\n",
            inputs.traversal_path_length
        ));
        // substring capture inputs
        if inputs.capture_group_ids.is_some() {
            let capture_group_ids = inputs
                .capture_group_ids
                .as_ref()
                .unwrap()
                .iter()
                .map(|num| format!("\"{num}\""))
                .collect::<Vec<_>>()
                .join(", ");
            toml.push_str(&format!("capture_group_ids = [{}]\n", capture_group_ids));
            let capture_group_starts = inputs
                .capture_group_starts
                .as_ref()
                .unwrap()
                .iter()
                .map(|num| format!("\"{num}\""))
                .collect::<Vec<_>>()
                .join(", ");
            toml.push_str(&format!(
                "capture_group_starts = [{}]\n",
                capture_group_starts
            ));
            let capture_group_start_indices = inputs
                .capture_group_start_indices
                .as_ref()
                .unwrap()
                .iter()
                .map(|num| format!("\"{num}\""))
                .collect::<Vec<_>>()
                .join(", ");
            toml.push_str(&format!(
                "capture_group_start_indices = [{}]\n",
                capture_group_start_indices
            ));
        };
        toml
    }
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
 * @param asserted_transition_length - The asserted traversal path length
 * @return - 0 if accept_state is reached, nonzero otherwise
 */
fn check_accept_state(
    next_state: Field,
    haystack_index: Field, 
    asserted_transition_length: Field
) -> Field {{
    // check if the next state is an accept state
    let accept_state_reached = {expression};
    let accept_state_reached_bool = (accept_state_reached == 0) as Field;

    // check if the haystack index is the asserted transition length
    // should equal 1 since haystack_index should be 1 less than asserted_transition length
    let asserted_path_traversed = (asserted_transition_length - haystack_index == 1) as Field;

    // if accept state reached, check asserted path traversed. Else return 1
    let valid_condition =
        (1 - accept_state_reached_bool) + (accept_state_reached_bool * asserted_path_traversed);
    assert(valid_condition == 1, "Accept state reached but not at asserted path end");

    // return accept_state reached value
    accept_state_reached
}}

"#
    )
}

/**
 * Unpacks a transition lookup value which includes:
 *  - if the transition is valid
 *  - if the transition is the start of a capture group
 *  - the id of the capture group
 *
 * @return the noir function to unpack the transition lookup value
 */
fn unpack_sparse_value_fn() -> String {
    format!(
        r#"
/**
 * Unpacks a transition lookup value
 * @dev 8 bit packed (0: valid transition, 1: start of capture group, 2-8: capture group id)
 * 
 * @return (valid, start_capture_group, capture_group_id)
 */
fn unpack_sparse_value(key: Field) -> (Field, Field, Field) {{
    let value = TRANSITION_TABLE.get(key);
    std::as_witness(value);
    let (is_valid, is_capture_start, capture_id) = unsafe {{ __unpack_sparse_value(value) }};
    is_valid.assert_max_bit_size::<1>();
    is_capture_start.assert_max_bit_size::<1>();
    capture_id.assert_max_bit_size::<6>();
    (is_valid, is_capture_start, capture_id)
}}

fn __unpack_sparse_value(value: Field) -> (Field, Field, Field) {{
    let x = value as u8;
    let is_valid = x & 1;
    let is_capture_start = (x & 2) >> 1;
    let capture_id = x >> 2;
    (is_valid as Field, is_capture_start as Field, capture_id as Field)
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
    transitions: &Vec<(usize, u8, u8, usize, Option<(usize, bool)>)>,
) -> SparseArray<FieldElement> {
    // let r = 256 * transitions.len();
    let r = 257;
    let mut entries = Vec::new();
    for (state_idx, start, end, dest, _) in transitions {
        let bytes = (*start..=*end).collect::<Vec<u8>>();
        for byte in bytes {
            let key = state_idx + (byte as usize * r) + (r * r * dest);
            entries.push(FieldElement::from(key));
        }
    }
    let values = vec![FieldElement::from(1u32); entries.len()];
    // assume max byte = 256 and max transitions = 200
    let max_size = FieldElement::from(transitions.len() + 256 * r + 200 * r * r);
    SparseArray::create(&entries, &values, max_size)
}

/**
 * Creates a packed sparse array for transitions
 *  byte 0: 1 if transition is valid, 0 if not
 *  byte 1: if the transition is the start of the capture group 1, 0 otherwise
 *  byte 2: if the transition is part of a capture group, the id of the capture group
 */
fn packed_transition_sparse_array(
    transitions: &Vec<(usize, u8, u8, usize, Option<(usize, bool)>)>,
) -> SparseArray<FieldElement> {
    let r = 257;
    let mut keys = Vec::new();
    let mut values = Vec::new();
    for (state_idx, start, end, dest, capture) in transitions {
        let bytes = (*start..=*end).collect::<Vec<u8>>();
        let (capture_id, capture_bool) = capture.unwrap_or((0, false));
        for byte in bytes {
            let key = state_idx + (byte as usize * r) + (r * r * dest);
            let value = 1u32 | (capture_bool as u32) << 1 | (capture_id as u32) << 2;
            keys.push(FieldElement::from(key));
            values.push(FieldElement::from(value));
        }
    }
    // assume max byte = 256 and max transitions = 200
    let max_size = FieldElement::from(transitions.len() + 256 * r + 200 * r * r);
    SparseArray::create(&keys, &values, max_size)
}

fn check_transition_fn() -> String {
    format!(
        r#"
fn check_transition(
    haystack_byte: Field,
    current_state: Field,
    next_state: Field,
    reached_end_state: Field
) {{
    let key = current_state + haystack_byte as Field * R as Field + next_state * R_SQUARED as Field;
    let transition_condition = TRANSITION_TABLE.get(key) - 1;
    let matched_condition = transition_condition * reached_end_state;
    assert(matched_condition == 0, "Invalid Transition");
}}

"#
    )
}

fn check_transition_with_captures_fn() -> String {
    format!(
        r#"
fn check_transition_with_captures(
    haystack_byte: Field,
    current_state: Field,
    next_state: Field,
    asserted_capture_group: Field,
    asserted_capture_start: Field,
    reached_end_state: Field
) {{
    let key = current_state + haystack_byte as Field * R as Field + next_state * R_SQUARED as Field;
    let (is_valid, is_capture_start, capture_id) = unpack_sparse_value(key);
    // check if the transition is valid
    let matched_condition = ((is_valid - 1)
        + ((asserted_capture_group - capture_id) * R as Field)
        + ((asserted_capture_start - is_capture_start) * R_SQUARED as Field))
        * reached_end_state;
    assert(matched_condition == 0, "Invalid Transition");
}}

"#
    )
}
