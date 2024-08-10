mod errors;
mod regex;
mod structs;

use errors::CompilerError;
use regex::get_regex_and_dfa;
use std::fs::File;
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
