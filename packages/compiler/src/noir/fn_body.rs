use super::{
    conditions::{
        force_match_condition, get_final_states_predicate, substring_extraction_conditions,
        get_end_states_predicate, get_substring_range_predicates
    },
    table::access_table,
    BYTE_SIZE,
};
use std::collections::BTreeSet;

pub fn match_def(
    regex_pattern: &str,
    accept_state_ids: &Vec<usize>,
    sparse_array: bool,
    force_match: bool,
) -> String {
    // table access according to lookup table arch
    let table_access_255 = access_table("255", sparse_array);
    let table_access_s_idx = access_table("s_idx", sparse_array);
    let final_states_predicate = get_final_states_predicate(accept_state_ids);
    // conditional returns and asserts based on whether the circuit should force a regex match
    let (return_type, return_statement, force_match_condition) =
        force_match_condition(force_match, final_states_predicate, None);
    format!(
        r#"
pub fn regex_match<let N: u32>(input: [u8; N]) {return_type} {{
    // regex: {regex_pattern}
    let mut s = 0;
    s = {table_access_255};
    for i in 0..input.len() {{
        let s_idx = s * {BYTE_SIZE} + input[i] as Field;
        std::as_witness(s_idx);
        s = {table_access_s_idx};
    }}
    {force_match_condition}
    {return_statement}
}}"#,
    )
    .trim()
    .to_owned()
}

pub fn capture_def(
    accept_state_ids: &Vec<usize>,
    substr_ranges: &Vec<BTreeSet<(usize, usize)>>,
    sparse_array: bool,
    force_match: bool
) -> String {
    // table access according to lookup table arch
    let table_access_255 = access_table("255", sparse_array);
    let table_access_s_next = access_table("s * 256 + temp", sparse_array);
    let table_access_s_next_temp = access_table("temp", sparse_array);

    // DFA predicates and conditional substring sequence building
    let final_states_predicate = get_final_states_predicate(accept_state_ids);
    let end_states_predicate = get_end_states_predicate(accept_state_ids);
    let substring_range_predicates = get_substring_range_predicates(substr_ranges);

    let substr_length = substr_ranges.len();


    // conditional returns and asserts based on whether the circuit should force a regex match
    let (return_type, return_statement, force_match_condition) =
        force_match_condition(
            force_match,
            final_states_predicate,
            Some(format!("SubstringMatch<{substr_length}>"))
        );

    format!(
        r#"
pub fn regex_match<let N: u32>(input: [u8; N]) {return_type} {{
    let pattern_match = unsafe {{ __regex_match(input) }};
    
    // "Previous" state
    let mut s: Field = 0;
    s = {table_access_255};
    // "Next"/upcoming state
    let mut s_next: Field = 0;
    let mut start_range = 0;
    let mut end_range = 0;

    // check the match
    for i in 0..N {{
        // state transition
        let temp = input[i] as Field;
        s_next = {table_access_s_next};
        let potential_s_next = {table_access_s_next_temp};
        if s_next == 0 {{
            s = 0;
            s_next = potential_s_next;
        }}
        std::as_witness(s_next);

        // range conditions for substring matches
        if ((start_range == 0) & (end_range == 0)) {{
            start_range = i as Field;
        }}
        if (({end_states_predicate}) & (end_range == 0)) {{
            end_range = i as Field + 1;
        }}
        {substring_range_predicates}
        s = s_next;
    }}
    // check final state
    {force_match_condition}
    // constrain extracted substrings to be in match range
    //let full_match = Sequence::new(start_range as u32, end_range as u32 - start_range as u32);
    //let full_match_end = full_match.end();
    // for i in 0..{substr_length} {{
    //     let substring = pattern_match.substrings.get_unchecked(i);
    //     let is_not_valid = i >= pattern_match.substrings.len();
    //     let index_check = substring.index >= full_match.index;
    //     let length_check = substring.end() <= full_match_end;
    //     let check = (index_check) | is_not_valid;
    //     assert(check, f"Substring {{i}} range is out of bounds of the full match found");
    // }}
    {return_statement}
}}
    "#
    )
}

pub fn unconstrained_capture_def(
    regex_pattern: &str,
    accept_state_ids: &Vec<usize>,
    substr_ranges: &Vec<BTreeSet<(usize, usize)>>,
    sparse_array: bool,
) -> String {
    // table access according to lookup table arch
    let table_access_255 = access_table("255", sparse_array);
    let table_access_s_next = access_table("s * 256 + temp", sparse_array);
    let table_access_s_next_temp = access_table("temp", sparse_array);

    // DFA predicates and conditional substring sequence building
    let final_states_predicate = get_final_states_predicate(accept_state_ids);
    let extraction_conditions = substring_extraction_conditions(substr_ranges, accept_state_ids);

    let substr_length = substr_ranges.len();
    format!(
        r#"
pub unconstrained fn __regex_match<let N: u32>(input: [u8; N]) -> SubstringMatch<{substr_length}> {{
    // regex: {regex_pattern}
    let mut substrings: BoundedVec<Sequence, {substr_length}> = BoundedVec::new();
    let mut current_substring = Sequence::default();
    let mut full_match = Sequence::default();

    // "Previous" state
    let mut s: Field = 0;
    s = {table_access_255};
    // "Next"/upcoming state
    let mut s_next: Field = 0;

    let mut consecutive_substr = 0;
    let mut complete = false;

    for i in 0..input.len() {{
        let temp = input[i] as Field;
        let mut reset = false;
        s_next = {table_access_s_next};
        let potential_s_next = {table_access_s_next_temp};
        if s_next == 0 {{
            reset = true;
            s = 0;
            s_next = potential_s_next;
        }}
        // If a substring was in the making, but the state was reset
        // we disregard previous progress because apparently it is invalid
        if (reset & (consecutive_substr == 1)) {{
            current_substring = Sequence::default();
            consecutive_substr = 0;
        }}
        // Fill up substrings
{extraction_conditions}
        s = s_next;
        if complete == true {{
            break;
        }}
    }}
    assert({final_states_predicate}, f"no match: {{s}}");
    // Add pending substring that hasn't been added
    if consecutive_substr == 1 {{
        substrings.push(current_substring);
        full_match.length = input.len() - full_match.index;
    }}

    

    SubstringMatch {{ substrings }}
}}
    "#
    )
}
