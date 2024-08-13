use crate::{
    errors::CompilerError,
    regex::{get_accepted_state, get_max_state},
    structs::RegexAndDFA,
};
use std::{
    fs::File,
    io::{BufWriter, Write},
    path::PathBuf,
};

fn dfa_to_regex_def_text(regex_and_dfa: &RegexAndDFA) -> String {
    let accepted_state = get_accepted_state(&regex_and_dfa.dfa).unwrap();
    let max_state = get_max_state(&regex_and_dfa.dfa);
    let mut text = format!("0\n{}\n{}\n", accepted_state, max_state);

    for (i, state) in regex_and_dfa.dfa.states.iter().enumerate() {
        for (next_state, chars) in state.transitions.iter() {
            for &char in chars {
                text += &format!("{} {} {}\n", i, next_state, char as u8);
            }
        }
    }
    text
}

pub(crate) fn gen_halo2_tables(
    regex_and_dfa: &RegexAndDFA,
    allstr_file_path: &PathBuf,
    substr_file_paths: &[PathBuf],
    gen_substrs: bool,
) -> Result<(), CompilerError> {
    let regex_text = dfa_to_regex_def_text(regex_and_dfa);
    std::fs::write(allstr_file_path, regex_text)?;

    if !gen_substrs {
        return Ok(());
    }

    for (idx, defs) in regex_and_dfa.substrings.substring_ranges.iter().enumerate() {
        let mut writer = BufWriter::new(File::create(&substr_file_paths[idx])?);
        let (starts, ends) = &regex_and_dfa
            .substrings
            .substring_boundaries
            .as_ref()
            .unwrap()[idx];

        writeln!(
            writer,
            "{}",
            starts
                .iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(" ")
        )?;
        writeln!(
            writer,
            "{}",
            ends.iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(" ")
        )?;

        let mut sorted_defs: Vec<_> = defs.iter().collect();
        sorted_defs.sort_unstable_by_key(|&(start, end)| (*start, *end));

        for &(cur, next) in &sorted_defs {
            writeln!(writer, "{} {}", cur, next)?;
        }
    }

    Ok(())
}
