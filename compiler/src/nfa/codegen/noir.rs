use std::collections::{HashMap, HashSet};

use crate::nfa::{
    NFAGraph,
    codegen::CircuitInputs,
    error::{NFAError, NFAResult},
};
use comptime::{FieldElement, SparseArray};
use serde::Serialize;

#[derive(Serialize)]
pub struct NoirInputs {
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

impl NFAGraph {
    /// Generate Noir code for the NFA
    pub fn generate_noir_code(
        &self,
        regex_pattern: &str,
        max_substring_bytes: Option<&[usize]>,
    ) -> NFAResult<String> {
        // get nfa graph data
        let (start_states, accept_states, transitions) = self.generate_circuit_data()?;

        let capture_group_set: HashSet<_> = transitions
            .iter()
            .filter_map(|(_, _, _, _, cap)| cap.map(|(id, _)| id))
            .collect();
        if !capture_group_set.is_empty() {
            if let Some(max_bytes) = max_substring_bytes {
                if max_bytes.len() < capture_group_set.len() {
                    return Err(NFAError::InvalidCapture(format!(
                        "Insufficient max_substring_bytes: need {} but got {}",
                        capture_group_set.len(),
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

        let has_capture_groups = !capture_group_set.is_empty();

        let mut code = String::new();

        // imports
        // todo: ability to change import path
        if has_capture_groups {
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
        let transition_array = match max_substring_bytes.is_some() {
            true => packed_transition_sparse_array(&transitions),
            false => transition_sparse_array(&transitions),
        };
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

        // regex match function doc
        code.push_str(&format!("/**\n"));
        code.push_str(&format!(" * Regex matching function\n"));
        code.push_str(&format!(" * @param in_haystack - The input haystack to search from\n"));
        code.push_str(&format!(" * @param match_start - The start index in the haystack for the subarray to match from\n"));
        code.push_str(&format!(" * @param match_length - The length of the subarray to extract from haystack\n"));
        code.push_str(&format!(" * @param current_states - The current states of the NFA at each index in the match subarray\n"));
        code.push_str(&format!(" * @param next_states - The next states of the NFA at each index in the match subarray\n"));
        if capture_group_set.len() > 0 {
            code.push_str(&format!(" * @param capture_group_ids - The ids of the capture groups in the match subarray\n"));
            code.push_str(&format!(" * @param capture_group_starts - The start positions of the capture groups in the match subarray\n"));
            code.push_str(&format!(" * @param capture_group_start_indices - The start indices of the capture groups in the match subarray\n"));
            code.push_str(&format!(" * @return - tuple of substring captures as dictated by the regular expression\n"));
        }
        code.push_str(&format!(" */\n"));

        // regex match function signature
        code.push_str(&format!(
            "pub fn regex_match<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(\n"
        ));
        code.push_str(&format!("    in_haystack: [u8; MAX_HAYSTACK_LEN],\n"));
        code.push_str(&format!("    match_start: u32,\n"));
        code.push_str(&format!("    match_length: u32,\n"));
        code.push_str(&format!("    current_states: [Field; MAX_MATCH_LEN],\n"));
        code.push_str(&format!("    next_states: [Field; MAX_MATCH_LEN],\n"));
        if (max_substring_bytes.is_some()) {
            code.push_str(&format!("    capture_group_ids: [Field; MAX_MATCH_LEN],\n"));
            code.push_str(&format!("    capture_group_starts: [Field; MAX_MATCH_LEN],\n"));
            code.push_str(&format!(
                "    capture_group_start_indices: [Field; NUM_CAPTURE_GROUPS],\n"
            ));
        }
        
        // define the return type according to existence of / qualities of capture groups
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

        // print the actual regex match being performed
        code.push_str(&format!("    // regex:{:?}\n", regex_pattern));

        // resize haystack to MAX_MATCH_LEN
        code.push_str(&format!("    // resize haystack \n"));
        code.push_str(&format!("    let haystack: [u8; MAX_MATCH_LEN] = select_subarray(in_haystack, match_start, match_length);\n\n"));
        code.push_str(&format!("    let mut reached_end_state = 1;\n"));

        // check start & range
        code.push_str(&format!("    check_start_state(current_states[0]);\n"));
        code.push_str(&format!("    for i in 0..MAX_MATCH_LEN-1 {{\n"));
        code.push_str(&format!("        // match length - 1 since current states should be 1 less than next states\n"));
        code.push_str(&format!(
            "        let in_range = (i < match_length - 1) as Field;\n"
        ));
        code.push_str(&format!(
            "        let matching_states = current_states[i + 1] - next_states[i];\n"
        ));
        code.push_str(&format!(
            "        assert(in_range * matching_states == 0, \"Invalid Transition Input\");\n"
        ));
        code.push_str(&format!("    }}\n"));

        // iterate through the haystack and check transitions
        code.push_str(&format!("    for i in 0..MAX_MATCH_LEN {{\n"));
        if max_substring_bytes.is_some() {
            // if capture groups exist, perform check that unpacks transition values
            code.push_str(&format!("        check_transition_with_captures(\n"));
            code.push_str(&format!("            TRANSITION_TABLE,\n"));
            code.push_str(&format!("            haystack[i] as Field,\n"));
            code.push_str(&format!("            current_states[i],\n"));
            code.push_str(&format!("            next_states[i],\n"));
            code.push_str(&format!("            capture_group_ids[i],\n"));
            code.push_str(&format!("            capture_group_starts[i],\n"));
            code.push_str(&format!("            reached_end_state\n"));
            code.push_str(&format!("        );\n"));
        } else {
            // if no capture groups exist, simple lookup
            code.push_str(&format!("        check_transition(\n"));
            code.push_str(&format!("            TRANSITION_TABLE,\n"));
            code.push_str(&format!("            haystack[i] as Field,\n"));
            code.push_str(&format!("            current_states[i],\n"));
            code.push_str(&format!("            next_states[i],\n"));
            code.push_str(&format!("            reached_end_state\n"));
            code.push_str(&format!("        );\n"));
        }
        // toggle off constraints/ set match assertion if end state found
        code.push_str(&format!(
            "        reached_end_state = reached_end_state * check_accept_state(\n"
        ));
        code.push_str(&format!("            next_states[i],\n"));
        code.push_str(&format!("            i as Field,\n"));
        code.push_str(&format!("            match_length as Field,\n"));
        code.push_str(&format!("        );\n"));
        code.push_str(&format!("    }}\n"));
        code.push_str(&format!(
            "    assert(reached_end_state == 0, \"Did not reach a valid end state\");\n"
        ));
        // add substring capture logic if capture groups exist
        if has_capture_groups {
            let mut ids = Vec::new();
            for capture_group_id in capture_group_set {
                let max_substring_bytes = if let Some(max_substring_bytes) = max_substring_bytes {
                    max_substring_bytes[capture_group_id - 1]
                } else {
                    return Err(NFAError::InvalidCapture(format!(
                        "Max substring bytes not provided for capture group {}",
                        capture_group_id
                    )));
                };

                code.push_str(&format!("     // Capture Group {}\n", capture_group_id));
                code.push_str(&format!("     let capture_{} = capture_substring::<MAX_MATCH_LEN, CAPTURE_{}_MAX_LENGTH, {}>(\n", capture_group_id, capture_group_id, capture_group_id));
                code.push_str(&format!("        haystack,\n"));
                code.push_str(&format!("        capture_group_ids,\n"));
                code.push_str(&format!("        capture_group_starts,\n"));
                code.push_str(&format!(
                    "        capture_group_start_indices[{}],\n",
                    capture_group_id - 1
                ));
                code.push_str(&format!("     );\n"));
                ids.push(format!("capture_{}", capture_group_id));
            }

            // define the return tuple
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
        toml.push_str(&format!("in_haystack = [{}]\n", haystack));
        toml.push_str(&format!("match_start = \"{}\"\n", inputs.match_start));
        toml.push_str(&format!("match_length = \"{}\"\n", inputs.match_length));
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
