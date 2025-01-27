use std::{
    collections::BTreeSet, collections::HashSet, fs::File, io::Write, iter::FromIterator,
    path::Path,
};

use itertools::Itertools;

use crate::structs::RegexAndDFA;

const ACCEPT_STATE_ID: &str = "accept";

pub fn gen_noir_fn(
    regex_and_dfa: &RegexAndDFA,
    path: &Path,
    gen_substrs: bool,
) -> Result<(), std::io::Error> {
    let noir_fn = to_noir_fn(regex_and_dfa, gen_substrs);
    let mut file = File::create(path)?;
    file.write_all(noir_fn.as_bytes())?;
    file.flush()?;
    Ok(())
}

/// Generates Noir code based on the DFA and whether a substring should be extracted.
///
/// # Arguments
///
/// * `regex_and_dfa` - The `RegexAndDFA` struct containing the regex pattern and DFA.
/// * `gen_substrs` - A boolean indicating whether to generate substrings.
///
/// # Returns
///
/// A `String` that contains the Noir code
fn to_noir_fn(regex_and_dfa: &RegexAndDFA, gen_substrs: bool) -> String {
    // Multiple accepting states are not supported
    // This is a vector nonetheless, to support an extra accepting state we'll use
    // to allow any character occurrences after the original accepting state
    let mut accept_state_ids: Vec<usize> = {
        let accept_states = regex_and_dfa
            .dfa
            .states
            .iter()
            .filter(|s| s.state_type == ACCEPT_STATE_ID)
            .map(|s| s.state_id)
            .collect_vec();
        assert!(
            accept_states.len() == 1,
            "there should be exactly 1 accept state"
        );
        accept_states
    };

    const BYTE_SIZE: u32 = 256; // u8 size
    let mut lookup_table_body = String::new();

    // curr_state + char_code -> next_state
    let mut rows: Vec<(usize, u8, usize)> = vec![];

    // $ support
    // In case that there is no end_anchor, we add an additional accepting state to which any
    // character occurence after the accepting state will go.
    // This needs to be a new state, otherwise substring extraction won't work correctly
    if !regex_and_dfa.has_end_anchor {
        let original_accept_id = accept_state_ids.get(0).unwrap().clone();
        // Create a new highest state
        let extra_accept_id = regex_and_dfa
            .dfa
            .states
            .iter()
            .max_by_key(|state| state.state_id)
            .map(|state| state.state_id)
            .unwrap()
            + 1;
        accept_state_ids.push(extra_accept_id);
        for char_code in 0..=254 {
            rows.push((original_accept_id, char_code, extra_accept_id));
            rows.push((extra_accept_id, char_code, extra_accept_id));
        }
    }
    for state in regex_and_dfa.dfa.states.iter() {
        for (&tran_next_state_id, tran) in &state.transitions {
            for &char_code in tran {
                rows.push((state.state_id, char_code, tran_next_state_id));
            }
        }
    }

    for (curr_state_id, char_code, next_state_id) in rows {
        lookup_table_body +=
            &format!("table[{curr_state_id} * {BYTE_SIZE} + {char_code}] = {next_state_id};\n",);
    }

    lookup_table_body = indent(&lookup_table_body, 1);
    let mut table_size = BYTE_SIZE as usize * regex_and_dfa.dfa.states.len();
    if !regex_and_dfa.has_end_anchor {
        table_size += BYTE_SIZE as usize;
    }
    let lookup_table = format!(
        r#"
comptime fn make_lookup_table() -> [Field; {table_size}] {{
    let mut table = [0; {table_size}];
{lookup_table_body}

    table
}}
    "#
    );

    // substring_ranges contains the transitions that belong to the substring
    let substr_ranges: &Vec<BTreeSet<(usize, usize)>> = &regex_and_dfa.substrings.substring_ranges;
    // Note: substring_boundaries is only filled if the substring info is coming from decomposed setting
    //  and will be empty in the raw setting (using json file for substr transitions). This is why substring_ranges is used here

    let final_states_condition_body = accept_state_ids
        .iter()
        .map(|id| format!("(s == {id})"))
        .collect_vec()
        .join(" | ");

    // If substrings have to be extracted, the function returns a vector of BoundedVec
    // otherwise there is no return type
    let fn_body = if gen_substrs {
        let mut first_condition = true;

        let mut conditions = substr_ranges
            .iter()
            .map(|range_set| {
                // Combine the range conditions into a single line using `|` operator
                let range_conditions = range_set
                    .iter()
                    .map(|(range_start, range_end)| {
                        format!("(s == {range_start}) & (s_next == {range_end})")
                    })
                    .collect::<Vec<_>>()
                    .join(" | ");

                // For the first condition, use `if`, for others, use `else if`
                let start_part = if first_condition {
                    first_condition = false;
                    "if"
                } else {
                    "else if"
                };

                // The body of the condition handling substring creation/updating
                format!(
                    "{start_part} ({range_conditions}) {{
    if (consecutive_substr == 0) {{
      current_substring.push(temp);
      consecutive_substr = 1;
    }} else if (consecutive_substr == 1) {{
      current_substring.push(temp);
    }}   
}}"
                )
            })
            .collect::<Vec<_>>()
            .join("\n");

        // Add the final else if for resetting the consecutive_substr
        let final_conditions = format!(
            "{conditions} else if ((consecutive_substr == 1) & (s_next == 0)) {{
    current_substring = BoundedVec::new();
    consecutive_substr = 0;
}} else if (consecutive_substr == 1) {{
    // The substring is done so \"save\" it
    substrings.push(current_substring);
    // reset the substring holder for next use
    current_substring = BoundedVec::new();
    consecutive_substr = 0;
}}"
        );

        conditions = indent(&final_conditions, 2); // Indent twice to align with the for loop's body

        format!(
            r#"
global table: [Field; {table_size}] = comptime {{ make_lookup_table() }};
pub fn regex_match<let N: u32>(input: [u8; N]) -> Vec<BoundedVec<Field, N>> {{
    // regex: {regex_pattern}
    let mut substrings: Vec<BoundedVec<Field, N>> = Vec::new();

    // "Previous" state
    let mut s: Field = 0;
    s = table[255];
    // "Next"/upcoming state
    let mut s_next: Field = 0;

    let mut consecutive_substr = 0;
    let mut current_substring = BoundedVec::new();

    for i in 0..input.len() {{
        let temp = input[i] as Field;
        let mut reset = false;
        s_next = table[s * 256 + temp];
        if s_next == 0 {{
          // Check if there is any transition that could be done from a "restart"
          s_next = table[temp];
          // whether the next state changes or not, we mark this as a reset.
          reset = true;
          s = 0;
        }}

        // If a substring was in the making, but the state was reset
        // we disregard previous progress because apparently it is invalid
        if (reset & (consecutive_substr == 1)) {{
            current_substring = BoundedVec::new();
            consecutive_substr = 0;
        }}
        // Fill up substrings
{conditions}
        s = s_next;
    }}
    assert({final_states_condition_body}, f"no match: {{s}}");
    // Add pending substring that hasn't been added
    if consecutive_substr == 1 {{
        substrings.push(current_substring);
    }}
    substrings
}}"#,
            regex_pattern = regex_and_dfa.regex_pattern.replace('\n', "\\n").replace('\r', "\\r")
        )
    } else {
        format!(
            r#"
global table = comptime {{ make_lookup_table() }};
pub fn regex_match<let N: u32>(input: [u8; N]) {{
    // regex: {regex_pattern}
    let mut s = 0;
    s = table[255];
    for i in 0..input.len() {{
        s = table[s * {BYTE_SIZE} + input[i] as Field];
    }}
    assert({final_states_condition_body}, f"no match: {{s}}");
}}"#,
            regex_pattern = regex_and_dfa.regex_pattern.replace('\n', "\\n").replace('\r', "\\r"),
        )
    };

    format!(
        r#"
        {fn_body}
        {lookup_table}
    "#
    )
    .trim()
    .to_owned()
}

/// Indents each line of the given string by a specified number of levels.
/// Each level adds four spaces to the beginning of non-whitespace lines.
fn indent(s: &str, level: usize) -> String {
    let indent_str = "    ".repeat(level);
    s.split("\n")
        .map(|s| {
            if s.trim().is_empty() {
                s.to_owned()
            } else {
                format!("{}{}", indent_str, s)
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}
