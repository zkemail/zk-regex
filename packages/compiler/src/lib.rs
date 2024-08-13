mod circom;
mod errors;
mod halo2;
mod regex;
mod structs;

use errors::CompilerError;
use halo2::gen_halo2_tables;
use itertools::Itertools;
use regex::get_regex_and_dfa;
use std::{fs::File, path::PathBuf};
use structs::DecomposedRegexConfig;

pub fn gen_from_decomposed(
    decomposed_regex_path: &str,
    halo2_dir_path: Option<&str>,
    circom_file_path: Option<&str>,
    circom_template_name: Option<&str>,
    gen_substrs: Option<bool>,
) -> Result<(), CompilerError> {
    let mut decomposed_regex_config: DecomposedRegexConfig =
        serde_json::from_reader(File::open(decomposed_regex_path)?)?;
    let gen_substrs = gen_substrs.unwrap_or(false);

    let regex_and_dfa = get_regex_and_dfa(&mut decomposed_regex_config)?;

    if let Some(halo2_dir_path) = halo2_dir_path {
        let halo2_dir_path = PathBuf::from(halo2_dir_path);
        let allstr_file_path = halo2_dir_path.join("allstr.txt");

        let num_public_parts = decomposed_regex_config
            .parts
            .iter()
            .filter(|part| part.is_public)
            .count();

        let substr_file_paths = (0..num_public_parts)
            .map(|idx| halo2_dir_path.join(format!("substr_{}.txt", idx)))
            .collect_vec();

        gen_halo2_tables(
            &regex_and_dfa,
            &allstr_file_path,
            &substr_file_paths,
            gen_substrs,
        )
        .expect("failed to generate halo2 tables");
    }

    Ok(())
}

pub fn gen_from_raw(
    raw_regex: &str,
    substrs_json_path: Option<&str>,
    halo2_dir_path: Option<&str>,
    circom_file_path: Option<&str>,
    template_name: Option<&str>,
    gen_substrs: Option<bool>,
) {
}
