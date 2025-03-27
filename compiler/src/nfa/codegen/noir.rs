use std::collections::{HashMap, HashSet};

use crate::nfa::{
    NFAGraph,
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

        let mut code = String::new();

        // imports
        code.push_str("mod common;\n");
        code.push_str("use common::SparseArray;\n\n");

        // codegen consts
        code.push_str(&format!("global R: u32 = 257;\n"));
        code.push_str(&format!("global R_SQUARED: u32 = R * R;\n\n"));

        code.push_str(&format!(
            "global TRANSITION_TABLE: {}\n\n",
            transition_array.to_noir_string(None)
        ));

        // add check for valid start states
        code.push_str(start_state_fn(&start_states).as_str());
        code.push_str(accept_state_fn(&accept_states).as_str());
        if max_substring_bytes.is_some() {
            code.push_str(unpack_sparse_value_fn().as_str());
            code.push_str(check_transition_with_captures_fn().as_str());
        } else {
            code.push_str(check_transition_fn().as_str());
        }

        code.push_str(&format!("pub fn regex_match<let N: u32>(\n"));
        code.push_str(&format!("    haystack: [u8; N],\n"));
        code.push_str(&format!("    current_states: [Field; N],\n"));
        code.push_str(&format!("    next_states: [Field; N],\n"));
        code.push_str(&format!("    transition_length: u32,\n"));
        code.push_str(&format!(") {{\n"));
        code.push_str(&format!("    // regex:{regex_pattern}\n"));
        code.push_str(&format!("    let mut reached_end_state = 1;\n"));
        code.push_str(&format!("    check_start_state(current_states[0]);\n"));
        code.push_str(&format!("    for i in 0..N-1 {{\n"));
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
        code.push_str(&format!("    for i in 0..N {{\n"));
        if max_substring_bytes.is_some() {
            code.push_str(&format!("        check_transition_with_captures(\n"));
            code.push_str(&format!("            haystack[i] as Field,\n"));
            code.push_str(&format!("            current_states[i],\n"));
            code.push_str(&format!("            next_states[i],\n"));
            code.push_str(&format!("            capture_ids[i],\n"));
            code.push_str(&format!("            capture_starts[i],\n"));
            code.push_str(&format!("            reached_end_state,\n"));
            code.push_str(&format!("        );\n"));
        } else {
            code.push_str(&format!("        check_transition(\n"));
            code.push_str(&format!("            haystack[i] as Field,\n"));
            code.push_str(&format!("            current_states[i],\n"));
            code.push_str(&format!("            next_states[i],\n"));
            code.push_str(&format!("            reached_end_state,\n"));
            code.push_str(&format!("        );\n"));
        }
        code.push_str(&format!(
            "        reached_end_state = reached_end_state * check_accept_state(next_state);\n"
        ));
        code.push_str(&format!("    }}\n"));
        code.push_str(&format!(
            "    assert(reached_end_state == 0, \"Did not reach a valid end state\");\n"
        ));
        code.push_str(&format!("}}\n\n"));
        code.push_str(&fn_test());
        Ok(code)
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
fn check_accept_state(next_state: Field) -> Field {{
    {expression}
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
    let (is_valid, is_capture_start, capture_id) = unsafe {{ __unpack_sparse_value(key) }};
    is_valid.assert_max_bit_size::<1>();
    is_capture_start.assert_max_bit_size::<1>();
    capture_id.assert_max_bit_size::<6>();
    (is_valid, is_capture_start, capture_id)
}}

fn __unpack_sparse_value(value: Field) -> (Field, Field, Field) {{
    let x = value as u8;
    let is_valid = x & 1;
    let is_capture_start = x & 2;
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
    let mut entries = Vec::new();
    for (state_idx, start, end, dest, capture) in transitions {
        let bytes = (*start..=*end).collect::<Vec<u8>>();
        let (capture_id, capture_bool) = capture.unwrap_or((0, false));
        for byte in bytes {
            let key = state_idx + (byte as usize * r) + (r * r * dest);
            let value = 1u32 | (capture_bool as u32) << 1 | (capture_id as u32) << 2;
            entries.push([FieldElement::from(key), FieldElement::from(value)]);
        }
    }
    // assume max byte = 256 and max transitions = 200
    let max_size = FieldElement::from(transitions.len() + 256 * r + 200 * r * r);
    SparseArray::create(&entries[0], &entries[1], max_size)
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
    asserted_capture_id: Field,
    asserted_capture_start: Field,
    reached_end_state: Field
) {{
    let key = current_state + haystack_byte as Field * R as Field + next_state * R_SQUARED as Field;
    let (is_valid, is_capture_start, capture_id) = unpack_sparse_value(key);
    // check if the transition is valid
    let matched_condition = ((is_valid - 1)
        + ((asserted_capture_group - capture_id) * R)
        + ((asserted_capture_start - is_capture_start) * R_SQUARED))
        * reached_end_state;
    assert(matched_condition == 0, "Invalid Transition");
}}

"#
    )
}

fn fn_test() -> String {
    format!(
        r#"

global HAYSTACK_LENGTH: u32 = 1024;

fn main(
    haystack: [u8; HAYSTACK_LENGTH],
    current_states: [Field; HAYSTACK_LENGTH],
    next_states: [Field; HAYSTACK_LENGTH],
    transition_length: u32,
) {{
    regex_match(haystack, current_states, next_states, transition_length);
}}

#[test]
fn test_regex_match() {{
    let haystack = [
        100, 107, 105, 109, 45, 115, 105, 103, 110, 97, 116, 117, 114, 101, 58, 118, 61, 49, 59, 32,
        97, 61, 114, 115, 97, 45, 115, 104, 97, 50, 53, 54, 59, 32, 99, 61, 114, 101, 108, 97, 120,
        101, 100, 47, 114, 101, 108, 97, 120, 101, 100, 59, 32, 100, 61, 103, 109, 97, 105, 108, 46,
        99, 111, 109, 59, 32, 115, 61, 50, 48, 50, 51, 48, 54, 48, 49, 59, 32, 116, 61, 49, 54, 57,
        52, 57, 56, 57, 56, 49, 50, 59, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];
    let current_states = [
        5, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 32, 33, 35, 36, 23, 32, 33,
        33, 33, 33, 33, 33, 33, 33, 33, 33, 35, 36, 23, 32, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33,
        33, 33, 33, 33, 33, 35, 36, 23, 32, 33, 33, 33, 33, 33, 33, 33, 33, 33, 35, 36, 23, 32, 33,
        33, 33, 33, 33, 33, 33, 33, 35, 36, 38, 39, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 0, 0,
        0, 0, 0, 0, 0, 0, 0,
    ];
    let next_states = [
        8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 32, 33, 35, 36, 23, 32, 33,
        33, 33, 33, 33, 33, 33, 33, 33, 33, 35, 36, 23, 32, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33,
        33, 33, 33, 33, 33, 35, 36, 23, 32, 33, 33, 33, 33, 33, 33, 33, 33, 33, 35, 36, 23, 32, 33,
        33, 33, 33, 33, 33, 33, 33, 35, 36, 38, 39, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 44, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    ];
    let transition_length: u32 = 91;
    regex_match(haystack, current_states, next_states, transition_length);
    // let capture_1_start_index = 80;
    // let capture_group_ids = [
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0,
    // ];
    // let capture_group_starts = [
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0,
    // ];
}}    
    "#
    )
}
