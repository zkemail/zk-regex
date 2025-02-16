use std::{
    collections::{BTreeSet, HashMap, HashSet},
    fs::File,
    io::Write,
    iter::FromIterator,
    path::Path,
};

use comptime::{FieldElement, SparseArray};
use itertools::Itertools;

use crate::structs::RegexAndDFA;

const ACCEPT_STATE_ID: &str = "accept";
const BYTE_SIZE: u32 = 256; // u8 size

pub fn gen_noir_fn(
    regex_and_dfa: &RegexAndDFA,
    path: &Path,
    gen_substrs: bool,
    sparse_array: Option<bool>,
) -> Result<(), std::io::Error> {
    println!("{}", regex_and_dfa.dfa);
    let use_sparse = sparse_array.unwrap_or(false);
    let noir_fn = to_noir_fn(regex_and_dfa, gen_substrs, use_sparse);
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
fn to_noir_fn(regex_and_dfa: &RegexAndDFA, gen_substrs: bool, sparse_array: bool) -> String {
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

    let mut table_size = BYTE_SIZE as usize * regex_and_dfa.dfa.states.len();
    if !regex_and_dfa.has_end_anchor {
        table_size += BYTE_SIZE as usize;
    }

    // handle conditional use of sparse array
    let mut table_str = String::new();
    if !sparse_array {
        let mut lut_body = String::new();
        for (curr_state_id, char_code, next_state_id) in rows {
            lut_body += &format!(
                "table[{curr_state_id} * {BYTE_SIZE} + {char_code}] = {next_state_id};\n",
            );
        }
        lut_body = indent(&lut_body, 1);

        table_str = format!(
            r#"
global table: [Field; {table_size}] = comptime {{ make_lookup_table() }};

comptime fn make_lookup_table() -> [Field; {table_size}] {{
    let mut table = [0; {table_size}];
    {lut_body}
    table
}}

        "#
        );
    } else {
        let mut keys: Vec<FieldElement> = Vec::new();
        let mut values: Vec<FieldElement> = Vec::new();
        for (curr_state_id, char_code, next_state_id) in rows {
            keys.push(FieldElement::from(
                curr_state_id * BYTE_SIZE as usize + char_code as usize,
            ));
            values.push(FieldElement::from(next_state_id));
        }

        let sparse_array: SparseArray<FieldElement> =
            SparseArray::create(&keys, &values, FieldElement::from(table_size));

        table_str = format!(
            r#"
global table: {sparse_str}

            "#,
            sparse_str = sparse_array.to_noir_string(None)
        );
    }

    // make sparse array in comptime

    // let sparse_array_str = sparse_array.to_noir_string(None);

    // substring_ranges contains the transitions that belong to the substring
    let substr_ranges: &Vec<BTreeSet<(usize, usize)>> = &regex_and_dfa.substrings.substring_ranges;
    // Note: substring_boundaries is only filled if the substring info is coming from decomposed setting
    //  and will be empty in the raw setting (using json file for substr transitions). This is why substring_ranges is used here

    let final_states_condition_body = accept_state_ids
        .iter()
        .map(|id| format!("(s == {id})"))
        .collect_vec()
        .join(" | ");
    let end_states_condition_body = match accept_state_ids.len() == 1 {
        true => format!(
            "(s == {}) & (s_next == {})",
            accept_state_ids[0], accept_state_ids[0]
        ),
        false => format!(
            "(s == {}) & (s_next == {})",
            accept_state_ids[0], accept_state_ids[1]
        ),
    };

    let end_range_condition = accept_state_ids
        .iter()
        .map(|id| format!("(s_next == {})", id))
        .join(" | ");

    let range_conditions = substr_ranges
        .iter()
        .enumerate()
        .map(|(index, range)| {
            let sorted = organize_states(range);
            ranges_to_predicate(sorted, index)
        })
        .join("");

    let final_range_predicate = {
        let mut cases = Vec::new();
        for i in 0..substr_ranges.len() {
            cases.push(format!("case_{}", i));
        }
        let case_str = cases.join(", ");
        indent(
            &format!(
                r#"
let substring_range_check = [{case_str}]
    .all(|case| case == true);

assert(substring_range_check, "substr array ranges wrong");
            "#
            ),
            2,
        )
    };

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
                let (start_part, start_index) = if first_condition {
                    first_condition = false;
                    let start_index_text = format!(
                        "if (consecutive_substr == 0) {{
        full_match.index = i;
        current_substring.index = i;
    }};\n"
                    );
                    ("if", start_index_text)
                } else {
                    ("else if", format!(""))
                };

                // The body of the condition handling substring creation/updating
                format!(
                    "{start_part} ({range_conditions}) {{
    {start_index}
    current_substring.length += 1;
    consecutive_substr = 1; 
}}"
                )
            })
            .collect::<Vec<_>>()
            .join("\n");

        // Add the final else if for resetting the consecutive_substr
        let final_conditions = format!(
            "{conditions} else if ((consecutive_substr == 1) & (s_next == 0)) {{
    current_substring = Sequence::default();
    full_match = Sequence::default();
    substrings = BoundedVec::new();
    consecutive_substr = 0;
}} else if {end_states_condition_body} {{
    full_match.length = i - full_match.index + 1;
    complete = true;
}} else if (consecutive_substr == 1) {{
    // The substring is done so \"save\" it
    substrings.push(current_substring);
    // reset the substring holder for next use
    current_substring = Sequence::default();
    consecutive_substr = 0;
}}"
        );

        conditions = indent(&final_conditions, 2); // Indent twice to align with the for loop's body

        format!(
            r#"
{table_str}
pub fn regex_match<let N: u32>(input: [u8; N]) -> BoundedVec<BoundedVec<u8, N>, {substr_length}> {{
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
        //let switch = (start_range + end_range != 0) as Field;
        //let keep_start_case = start_range - (start_range * switch);
        //let set_start_i_case = (1 - switch) * i as Field;
        //start_range = keep_start_case + set_start_i_case;
        //if (({end_range_condition}) & (end_range == 0)) {{
        //    end_range = i as Field + 1;
        //}}
        if (({end_states_condition_body}) & (end_range == 0)) {{
            end_range = i as Field + 1;
        }}

        {range_conditions}

        {final_range_predicate}

        s = s_next;
    }}
    // check final state
    //assert({final_states_condition_body}, f"no match: {{s}}");
    let matched = {final_states_condition_body};
    // constrain extracted substrings to be in match range
    let full_match = Sequence::new(start_range as u32, end_range as u32 - start_range as u32);
    let full_match_end = full_match.end();
    for i in 0..{substr_length} {{
        let substring = pattern_match.substrings.get_unchecked(i);
        let is_not_valid = i >= pattern_match.substrings.len();
        let index_check = substring.index >= full_match.index;
        let length_check = substring.end() <= full_match_end;
        let check = (index_check) | is_not_valid;
        assert(check, f"Substring {{i}} range is out of bounds of the full match found");
    }}

    // extract substrings
    let mut substrings: BoundedVec<BoundedVec<u8, N>, {substr_length}> = BoundedVec::new();
    for i in 0..{substr_length} {{
        let substring = pattern_match.substrings.get_unchecked(i);
        let mut extracted_substring = extract_substring(substring, input);
        let mut len = substrings.len() + 1;
        if i >= pattern_match.substrings.len() {{
            extracted_substring = BoundedVec::new();
            len = substrings.len();
        }}
        substrings.len = len;
        substrings.storage[i] = extracted_substring;
    }}

    substrings
}}

pub unconstrained fn __regex_match<let N: u32>(input: [u8; N]) -> RegexMatch<N, {substr_length}> {{
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
{conditions}
        s = s_next;
        if complete == true {{
            break;
        }}
    }}
    assert({final_states_condition_body}, f"no match: {{s}}");
    // Add pending substring that hasn't been added
    if consecutive_substr == 1 {{
        substrings.push(current_substring);
        full_match.length = input.len() - full_match.index;
    }}

    // make masked array
    let mut masked = [0; N];
    for i in 0..substrings.len() {{
        let substring = substrings.get(i);
        let start_index = substring.index;
        let end_index = start_index + substring.length;
        for j in start_index..end_index {{
            masked[j] = input[j];
        }}
    }}

    RegexMatch {{ masked, full_match, substrings }}
}}

{COMMON_NOIR_CODE}
"#,
            regex_pattern = escape_non_ascii(
                &regex_and_dfa
                    .regex_pattern
                    .replace('\n', "\\n")
                    .replace('\r', "\\r")
            ),
            table_access_255 = access_table("255", sparse_array),
            table_access_s_next = access_table("s * 256 + temp", sparse_array),
            table_access_s_next_temp = access_table("temp", sparse_array),
            substr_length = regex_and_dfa.substrings.substring_ranges.len(),
        )
    } else {
        format!(
            r#"
{table_str}
pub fn regex_match<let N: u32>(input: [u8; N]) {{
    // regex: {regex_pattern}
    let mut s = 0;
    s = {table_access_255};
    for i in 0..input.len() {{
        let s_idx = s * {BYTE_SIZE} + input[i] as Field;
        std::as_witness(s_idx);
        s = {table_access_s_idx};
    }}
    assert({final_states_condition_body}, f"no match: {{s}}");
}}"#,
            regex_pattern = escape_non_ascii(
                &regex_and_dfa
                    .regex_pattern
                    .replace('\n', "\\n")
                    .replace('\r', "\\r")
            ),
            table_access_255 = access_table("255", sparse_array),
            table_access_s_idx = access_table("s_idx", sparse_array),
        )
    };

    format!(
        r#"
        {fn_body}
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

/// Access table by array index or sparse API index
fn access_table(s: &str, sparse: bool) -> String {
    match sparse {
        true => format!("table.get({})", s),
        false => format!("table[{}]", s),
    }
}

// Noir does not like non-ascii comments so use this to show regex
fn escape_non_ascii(input: &str) -> String {
    input
        .chars()
        .map(|c| {
            if c.is_ascii() {
                c.to_string()
            } else {
                format!("\\u{{{:04x}}}", c as u32)
            }
        })
        .collect()
}

#[derive(Debug, Clone)]
struct StateMatch {
    single: usize,
    match_vec: Vec<usize>,
    s: bool,
}

fn organize_states(states: &BTreeSet<(usize, usize)>) -> Vec<StateMatch> {
    use std::collections::{HashMap, HashSet};

    // Create maps for forward and reverse connections
    let mut s_to_next: HashMap<usize, Vec<usize>> = HashMap::new();
    let mut next_to_s: HashMap<usize, Vec<usize>> = HashMap::new();

    for &(s, next) in states {
        s_to_next.entry(s).or_default().push(next);
        next_to_s.entry(next).or_default().push(s);
    }

    // Helper function to get sorted unique values
    let get_unique_sorted = |v: &Vec<usize>| -> Vec<usize> {
        let mut unique: Vec<usize> = v.iter().copied().collect();
        unique.sort_unstable();
        unique.dedup();
        unique
    };

    let mut result = Vec::new();
    let mut covered = HashSet::new();

    // First pass: Find nodes that have multiple outgoing edges
    for (&num, matches_found) in &s_to_next {
        let matches = get_unique_sorted(matches_found);
        if matches.len() > 1 {
            result.push(StateMatch {
                single: num,
                match_vec: matches.clone(),
                s: true,
            });
            for &m in &matches {
                covered.insert((num, m));
            }
        }
    }

    // Second pass: Find remaining edges that need to be covered
    let mut uncovered = states
        .iter()
        .filter(|&&(s, next)| !covered.contains(&(s, next)))
        .collect::<Vec<_>>();

    // Group remaining by destination
    let mut dest_groups: HashMap<usize, Vec<usize>> = HashMap::new();
    for &(s, next) in &uncovered {
        dest_groups.entry(*next).or_default().push(*s);
    }

    // Add any groups with multiple sources
    for (dest, sources) in dest_groups {
        let mut sources = sources;
        sources.sort_unstable();
        result.push(StateMatch {
            single: dest,
            match_vec: sources,
            s: false,
        });
    }

    // Sort results by single value
    result.sort_by_key(|sm| sm.single);

    result
}

fn ranges_to_predicate(states: Vec<StateMatch>, index: usize) -> String {
    let cases = states
        .iter()
        .map(|state| {
            let (single_label, matches_label) = match state.s {
                true => ("s", "s_next"),
                false => ("s_next", "s"),
            };
            let matches_str = state
                .match_vec
                .iter()
                .map(|state| format!("({} == {})", matches_label, state))
                .join(" | ");
            format!("({} == {}) & ({})", single_label, state.single, matches_str)
        })
        .join(",\n\t");
    indent(
        &format!(
            r#"
let range_{index} = pattern_match.substrings.get_unchecked({index}).in_range(i);
let case_{index} = [
    {cases}
].any(|case| case == true) | !range_{index};
"#
        ),
        2,
    )
}
const COMMON_NOIR_CODE: &str = r#"
pub struct Sequence {
    index: u32,
    length: u32,
}

impl Sequence {
    pub fn new(index: u32, length: u32) -> Self {
        Self { index, length }
    }

    pub fn default() -> Self {
        Self { index: 0, length: 0 }
    }

    pub fn end(self) -> u32 {
        self.index + self.length
    }

    pub fn in_range(self, index: u32) -> bool {
        index >= self.index & index < self.end()
    }
}

pub struct RegexMatch<let INPUT_LENGTH: u32, let NUM_SUBSTRINGS: u32> {
    masked: [u8; INPUT_LENGTH],
    full_match: Sequence,
    substrings: BoundedVec<Sequence, NUM_SUBSTRINGS>,
}

pub fn extract_substring<let INPUT_LENGTH: u32, let MAX_SUBSTRING_LENGTH: u32>(
    substring_sequence: Sequence,
    input: [u8; INPUT_LENGTH],
) -> BoundedVec<u8, MAX_SUBSTRING_LENGTH> {
    let mut substring: BoundedVec<u8, MAX_SUBSTRING_LENGTH> = unsafe { __extract_substring(substring_sequence, input) };
    assert(substring_sequence.length == substring.len(), "length mismatch");
    for i in 0..MAX_SUBSTRING_LENGTH {
        // hack for index to never exceed array bounds
        // must be constrained to be true when matching is required to prevent 0's passing when shouldn't
        // @dev while this adds constraints in worse case it can be more efficient if MAX_SUBSTRING_LENGTH < INPUT_LENGTH
        let input_range_check = substring_sequence.index + i < INPUT_LENGTH;
        let index = (substring_sequence.index + i) as Field * input_range_check as Field;

        // range where input should match substring
        let sequence_range_check = i >= substring_sequence.length;
        
        // constrain array construction if in range
        let expected_byte = input[index];
        let byte = substring.get_unchecked(i);
        let matched = (expected_byte as Field == byte as Field);
        assert(matched | sequence_range_check, "incorrect substring construction");
    }
    substring
}

unconstrained fn __extract_substring<let INPUT_LENGTH: u32, let MAX_SUBSTRING_LENGTH: u32>(
    substring_sequence: Sequence,
    input: [u8; INPUT_LENGTH],
) -> BoundedVec<u8, MAX_SUBSTRING_LENGTH> {
    let mut substring: BoundedVec<u8, MAX_SUBSTRING_LENGTH> = BoundedVec::new();
    for i in 0..substring_sequence.length {
        let byte = input[substring_sequence.index + i];
        substring.push(byte);
    }
    substring
}
    "#;
