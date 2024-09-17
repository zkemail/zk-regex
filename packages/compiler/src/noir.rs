use std::{collections::HashSet, fs::File, io::Write, iter::FromIterator, path::Path};

use itertools::Itertools;

use crate::structs::RegexAndDFA;

const ACCEPT_STATE_ID: &str = "accept";

pub fn gen_noir_fn(regex_and_dfa: &RegexAndDFA, path: &Path) -> Result<(), std::io::Error> {
    let noir_fn = to_noir_fn(regex_and_dfa);
    let mut file = File::create(path)?;
    file.write_all(noir_fn.as_bytes())?;
    file.flush()?;
    Ok(())
}

fn to_noir_fn(regex_and_dfa: &RegexAndDFA) -> String {
    let accept_state_ids = {
        let accept_states = regex_and_dfa
            .dfa
            .states
            .iter()
            .filter(|s| s.state_type == ACCEPT_STATE_ID)
            .map(|s| s.state_id)
            .collect_vec();
        assert!(accept_states.len() > 0, "no accept states");
        accept_states
    };

    const BYTE_SIZE: u32 = 256; // u8 size
    let mut lookup_table_body = String::new();

    // curr_state + char_code -> next_state
    let mut rows: Vec<(usize, u8, usize)> = vec![];

    for state in regex_and_dfa.dfa.states.iter() {
        for (&tran_next_state_id, tran) in &state.transitions {
            for &char_code in tran {
                rows.push((state.state_id, char_code, tran_next_state_id));
            }
        }
        if state.state_type == ACCEPT_STATE_ID {
            let existing_char_codes = &state
                .transitions
                .iter()
                .flat_map(|(_, tran)| tran.iter().copied().collect_vec())
                .collect::<HashSet<_>>();
            let all_char_codes = HashSet::from_iter(0..=255);
            let mut char_codes = all_char_codes.difference(existing_char_codes).collect_vec();
            char_codes.sort(); // to be deterministic
            for &char_code in char_codes {
                rows.push((state.state_id, char_code, state.state_id));
            }
        }
    }

    for (curr_state_id, char_code, next_state_id) in rows {
        lookup_table_body +=
            &format!("table[{curr_state_id} * {BYTE_SIZE} + {char_code}] = {next_state_id};\n",);
    }

    lookup_table_body = indent(&lookup_table_body);
    let table_size = BYTE_SIZE as usize * regex_and_dfa.dfa.states.len();
    let lookup_table = format!(
        r#"
comptime fn make_lookup_table() -> [Field; {table_size}] {{
    let mut table = [0; {table_size}];
{lookup_table_body}

    table
}}
    "#
    );

    let final_states_condition_body = accept_state_ids
        .iter()
        .map(|id| format!("(s == {id})"))
        .collect_vec()
        .join(" | ");
    let fn_body = format!(
        r#"
global table = comptime {{ make_lookup_table() }};
pub fn regex_match<let N: u32>(input: [u8; N]) {{
    // regex: {regex_pattern}
    let mut s = 0;
    for i in 0..input.len() {{
        s = table[s * {BYTE_SIZE} + input[i] as Field];
    }}
    assert({final_states_condition_body}, f"no match: {{s}}");
}}
    "#,
        regex_pattern = regex_and_dfa.regex_pattern,
    );
    format!(
        r#"
        {fn_body}
        {lookup_table}
    "#
    )
    .trim()
    .to_owned()
}

fn indent(s: &str) -> String {
    s.split("\n")
        .map(|s| {
            if s.trim().is_empty() {
                s.to_owned()
            } else {
                format!("{}{}", "    ", s)
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}
