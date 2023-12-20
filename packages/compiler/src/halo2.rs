use crate::js_caller::*;
use crate::*;

use itertools::Itertools;




use std::io::BufWriter;
use std::io::Write;

use std::path::PathBuf;
use std::{fs::File};


impl RegexAndDFA {
    pub fn gen_halo2_tables(
        &self,
        allstr_file_path: &PathBuf,
        substr_file_pathes: &[PathBuf],
        gen_substrs: bool,
    ) -> Result<(), CompilerError> {
        let regex_text = self.dfa_to_regex_def_text()?;
        let mut regex_file = File::create(allstr_file_path)?;
        write!(regex_file, "{}", regex_text)?;
        regex_file.flush()?;
        if !gen_substrs {
            return Ok(());
        }
        let substr_endpoints_array = self.substrs_defs.substr_endpoints_array.as_ref().unwrap();
        // let max_bytes = self.substrs_defs.max_bytes.as_ref().unwrap();
        for (idx, defs) in self.substrs_defs.substr_defs_array.iter().enumerate() {
            let mut writer = BufWriter::new(File::create(&substr_file_pathes[idx])?);
            // let max_size = max_bytes[idx];
            // writer.write_fmt(format_args!("{}\n", &max_size))?;
            // writer.write_fmt(format_args!("0\n{}\n", self.max_byte_size - 1))?;
            let mut starts_str = "".to_string();
            let starts = substr_endpoints_array[idx]
                .0
                .iter()
                .sorted_by(|a, b| a.cmp(b));
            for start in starts {
                starts_str += &format!("{} ", start);
            }
            writer.write_fmt(format_args!("{}\n", starts_str))?;
            let mut ends_str = "".to_string();
            let ends = substr_endpoints_array[idx]
                .1
                .iter()
                .sorted_by(|a, b| a.cmp(b));
            for end in ends {
                ends_str += &format!("{} ", end);
            }
            writer.write_fmt(format_args!("{}\n", ends_str))?;
            let mut defs = defs.iter().collect::<Vec<&(usize, usize)>>();
            defs.sort_by(|a, b| {
                let start_cmp = a.0.cmp(&b.0);
                let end_cmp = a.1.cmp(&b.1);
                if start_cmp == std::cmp::Ordering::Equal {
                    end_cmp
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

    pub fn dfa_to_regex_def_text(&self) -> Result<String, JsCallerError> {
        let accepted_state =
            get_accepted_state(&self.dfa_val).ok_or(JsCallerError::NoAcceptedState)?;
        let max_state = get_max_state(&self.dfa_val)?;
        let mut text = "0\n".to_string();
        text += &format!("{}\n", accepted_state.to_string());
        text += &format!("{}\n", max_state.to_string());
        for (i, val) in self.dfa_val.iter().enumerate() {
            for (key, next_node_val) in val["edges"]
                .as_object()
                .ok_or(JsCallerError::InvalidEdges(val["edges"].clone()))?
                .iter()
            {
                let key_list: Vec<String> = serde_json::from_str(&key)?;
                for key_char in key_list.iter() {
                    let key_char: char = key_char.chars().collect::<Vec<char>>()[0];
                    let next_node = next_node_val
                        .as_u64()
                        .ok_or(JsCallerError::InvalidNodeValue(next_node_val.clone()))?
                        as usize;
                    // println!("i {} next {} char {}", i, next_node, key_char as u8);
                    text += &format!(
                        "{} {} {}\n",
                        i.to_string(),
                        next_node.to_string(),
                        (key_char as u8).to_string()
                    );
                }
            }
        }
        Ok(text)
    }
}
