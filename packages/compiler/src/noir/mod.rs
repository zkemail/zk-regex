mod common;
mod conditions;
mod fn_body;
mod table;
mod utils;

use itertools::Itertools;
use std::{fs::File, io::Write, path::Path, collections::BTreeSet};

use crate::structs::RegexAndDFA;
use self::{
    table::make_lookup_table,
    utils::escape_non_ascii,
    fn_body::{match_def, capture_def, unconstrained_capture_def},
    common::get_common_regex_def
};

const ACCEPT_STATE_ID: &str = "accept";
const BYTE_SIZE: u32 = 256; // u8 size

type TableRows = Vec<(usize, u8, usize)>;

/**
 * Codegen Noir ZK Regex
 *
 * @param regex_and_dfa - the regex and dfa to generate the noir function for
 * @param path - the path to write the noir function to
 * @param gen_substrs - whether to generate substring matches
 * @param sparse_array - whether to use a sparse array for the DFA
 * @param force_match - whether the circuit should force a match or export a boolean
 * @param add_common - optional dependency import to include for regex common definitions
 */
pub fn gen_noir_fn(
    regex_and_dfa: &RegexAndDFA,
    path: &Path,
    gen_substrs: bool,
    sparse_array: Option<bool>,
    force_match: Option<bool>,
    use_common: Option<&str>
) -> Result<(), std::io::Error> {
    println!("{}", regex_and_dfa.dfa);
    let use_sparse = sparse_array.unwrap_or(false);
    let force_match = force_match.unwrap_or(true);
    let noir_fn = to_noir_fn(regex_and_dfa, gen_substrs, use_sparse, force_match, use_common);
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
/// * `sparse_array` - A boolean indicating whether to use a sparse array for the DFA.
/// * `force_match` - A boolean indicating whether the circuit should force a match or export a boolean.
/// * `use_common` - An optional dependency import to include for regex common definitions.
///
/// # Returns
///
/// A `String` that contains the Noir code
fn to_noir_fn(
    regex_and_dfa: &RegexAndDFA,
    gen_substrs: bool,
    sparse_array: bool,
    force_match: bool,
    use_common: Option<&str>,
) -> String {
    // Regex pattern
    let mut regex_pattern =  
        regex_and_dfa
            .regex_pattern
            .replace('\n', "\\n")
            .replace('\r', "\\r");
    println!("Generating Noir code for regex: {}", regex_pattern);
    regex_pattern = escape_non_ascii(&regex_pattern);
    // Parse the accepted states and rows for the DFA lookup table
    let (accept_state_ids, rows) = parse_dfa(regex_and_dfa);

    // Determine the needed size of the lookup table
    let mut table_size = BYTE_SIZE as usize * regex_and_dfa.dfa.states.len();
    if !regex_and_dfa.has_end_anchor {
        table_size += BYTE_SIZE as usize;
    }

    // generate the lookup table
    let table_def = make_lookup_table(&rows, table_size, sparse_array);

    // let sparse_array_str = sparse_array.to_noir_string(None);

    // substring_ranges contains the transitions that belong to the substring
    let substr_ranges: &Vec<BTreeSet<(usize, usize)>> = &regex_and_dfa.substrings.substring_ranges;
    // Note: substring_boundaries is only filled if the substring info is coming from decomposed setting
    //  and will be empty in the raw setting (using json file for substr transitions). This is why substring_ranges is used here

    // generate function body
    let regex_match_def = match gen_substrs {
        true => {
            let constrained = capture_def(&accept_state_ids, substr_ranges, sparse_array, force_match);
            let unconstrained = unconstrained_capture_def(&regex_pattern, &accept_state_ids, substr_ranges, sparse_array);
            format!(r#"
{constrained}
{unconstrained}
            "#)
        }
        false => match_def(&regex_pattern, &accept_state_ids, sparse_array, force_match),
    };

    // codegen the file
    let mut regex_codegen = format!(
        r#"
{table_def}
{regex_match_def}
        "#
    );
    if use_common.is_none() {
        let common_regex_def = get_common_regex_def();

        regex_codegen = format!(
            r#"
{regex_codegen}
{common_regex_def}
            "#,
        );
    } else {
        let common_import = format!("use {}::Sequence;", use_common.unwrap());
        regex_codegen = format!(
            r#"
{common_import}
{regex_codegen}
            "#,
        );
    }

    regex_codegen
}

/**
 * Parse the accepted states and rows for the DFA lookup table
 * 
 * @param regex_and_dfa - the regex and dfa to generate the noir function for
 * @returns
 *    - the accepted states
 *    - the rows for the DFA lookup table
 */
fn parse_dfa(regex_and_dfa: &RegexAndDFA) -> (Vec<usize>, TableRows)  {
    // Multiple accepting states are not supported
    // This is a vector nonetheless, to support an extra accepting state we'll use
    // to allow any character occurrences after the original accepting state
    let mut accept_state_ids = regex_and_dfa
        .dfa
        .states
        .iter()
        .filter(|s| s.state_type == ACCEPT_STATE_ID)
        .map(|s| s.state_id)
        .collect_vec();
    assert!(
        accept_state_ids.len() == 1,
        "there should be exactly 1 accept state"
    );
    
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

    // interstitial states
    for state in regex_and_dfa.dfa.states.iter() {
        for (&tran_next_state_id, tran) in &state.transitions {
            for &char_code in tran {
                rows.push((state.state_id, char_code, tran_next_state_id));
            }
        }
    };

    (accept_state_ids, rows)
}
