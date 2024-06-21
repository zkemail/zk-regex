use std::collections::BTreeSet;
use std::fs::File;
use std::io::{BufWriter, Write};
use std::path::PathBuf;

use crate::{get_accepted_state, get_max_state, CompilerError, RegexAndDFA};

impl RegexAndDFA {
    fn extract_endpoints_from_defs(defs: &BTreeSet<(usize, usize)>) -> (Vec<usize>, Vec<usize>) {
        let starts: Vec<usize> = defs.iter().map(|(start, _)| *start).collect();
        let ends: Vec<usize> = defs.iter().map(|(_, end)| *end).collect();
        (starts, ends)
    }

    pub fn gen_halo2_tables(
        &self,
        allstr_file_path: &PathBuf,
        substr_file_paths: &[PathBuf],
        gen_substrs: bool,
    ) -> Result<(), CompilerError> {
        let regex_text = self.dfa_to_regex_def_text();
        let mut regex_file = File::create(allstr_file_path)?;
        write!(regex_file, "{}", regex_text)?;
        regex_file.flush()?;

        if !gen_substrs {
            return Ok(());
        }

        for (idx, defs) in self.substrs_defs.substr_defs_array.iter().enumerate() {
            let mut writer = BufWriter::new(File::create(&substr_file_paths[idx])?);

            let (starts, ends) = Self::extract_endpoints_from_defs(defs);
            let starts_str = starts
                .iter()
                .map(|s| s.to_string())
                .collect::<Vec<_>>()
                .join(" ");
            writer.write_fmt(format_args!("{}\n", starts_str))?;
            let ends_str = ends
                .iter()
                .map(|e| e.to_string())
                .collect::<Vec<_>>()
                .join(" ");
            writer.write_fmt(format_args!("{}\n", ends_str))?;

            let mut defs = defs.iter().collect::<Vec<&(usize, usize)>>();
            defs.sort_by(|a, b| {
                let start_cmp = a.0.cmp(&b.0);
                if start_cmp == std::cmp::Ordering::Equal {
                    a.1.cmp(&b.1)
                } else {
                    start_cmp
                }
            });

            for (cur, next) in defs.iter() {
                writer.write_fmt(format_args!("{} {}\n", cur, next))?;
            }
        }
        Ok(())
    }

    pub fn dfa_to_regex_def_text(&self) -> String {
        let accepted_state = get_accepted_state(&self.dfa_val).unwrap();
        let max_state = get_max_state(&self.dfa_val);
        let mut text = format!("0\n{}\n{}\n", accepted_state, max_state);

        for (i, state) in self.dfa_val.states.iter().enumerate() {
            for (next_state, chars) in state.edges.iter() {
                for &char in chars {
                    let char_u8 = char as u8;
                    text += &format!("{} {} {}\n", i, next_state, char_u8);
                }
            }
        }
        text
    }
}

#[cfg(test)]
mod tests {
    use crate::{DecomposedRegexConfig, RegexPartConfig};
    use std::collections::VecDeque;

    #[test]
    fn test_dfa_to_regex_def_text() {
        let regex_part_config = RegexPartConfig {
            is_public: false,
            regex_def: "m[01]+-[ab];".to_string(),
        };
        let mut decomposed_regex_config = DecomposedRegexConfig {
            parts: VecDeque::from(vec![regex_part_config]),
        };

        let regex_and_dfa = decomposed_regex_config
            .to_regex_and_dfa()
            .expect("failed to convert the decomposed regex to dfa");

        let regex_def_text = regex_and_dfa.dfa_to_regex_def_text();
        println!("result: {}", regex_def_text);
    }
}
