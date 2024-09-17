mod circom;
mod errors;
mod halo2;
mod noir;
mod regex;
mod structs;
mod wasm;

use circom::gen_circom_template;
use errors::CompilerError;
use halo2::gen_halo2_tables;
use itertools::Itertools;
use noir::gen_noir_fn;
use regex::{create_regex_and_dfa_from_str_and_defs, get_regex_and_dfa};
use std::{fs::File, path::PathBuf};
use structs::{DecomposedRegexConfig, RegexAndDFA, SubstringDefinitionsJson};

/// Loads substring definitions from a JSON file or creates a default one.
///
/// # Arguments
///
/// * `substrs_json_path` - An optional path to the JSON file containing substring definitions.
///
/// # Returns
///
/// A `Result` containing either the loaded `SubstringDefinitionsJson` or a `CompilerError`.
fn load_substring_definitions_json(
    substrs_json_path: Option<&str>,
) -> Result<SubstringDefinitionsJson, CompilerError> {
    match substrs_json_path {
        Some(path) => {
            let file = File::open(path)?;
            serde_json::from_reader(file).map_err(CompilerError::JsonParseError)
        }
        None => Ok(SubstringDefinitionsJson {
            transitions: vec![vec![]],
        }),
    }
}

/// Generates output files for Halo2 and Circom based on the provided regex and DFA.
///
/// # Arguments
///
/// * `regex_and_dfa` - The `RegexAndDFA` struct containing the regex pattern and DFA.
/// * `halo2_dir_path` - An optional path to the directory for Halo2 output files.
/// * `circom_file_path` - An optional path to the Circom output file.
/// * `circom_template_name` - An optional name for the Circom template.
/// * `num_public_parts` - The number of public parts in the regex.
/// * `gen_substrs` - A boolean indicating whether to generate substrings.
///
/// # Returns
///
/// A `Result` indicating success or a `CompilerError`.
fn generate_outputs(
    regex_and_dfa: &RegexAndDFA,
    halo2_dir_path: Option<&str>,
    circom_file_path: Option<&str>,
    circom_template_name: Option<&str>,
    noir_file_path: Option<&str>,
    num_public_parts: usize,
    gen_substrs: bool,
) -> Result<(), CompilerError> {
    if let Some(halo2_dir_path) = halo2_dir_path {
        let halo2_dir_path = PathBuf::from(halo2_dir_path);
        let allstr_file_path = halo2_dir_path.join("allstr.txt");
        let substr_file_paths = (0..num_public_parts)
            .map(|idx| halo2_dir_path.join(format!("substr_{}.txt", idx)))
            .collect_vec();

        gen_halo2_tables(
            regex_and_dfa,
            &allstr_file_path,
            &substr_file_paths,
            gen_substrs,
        )?;
    }

    if let Some(circom_file_path) = circom_file_path {
        let circom_file_path = PathBuf::from(circom_file_path);
        let circom_template_name = circom_template_name
            .expect("circom template name must be specified if circom file path is specified");

        gen_circom_template(
            regex_and_dfa,
            &circom_file_path,
            &circom_template_name,
            gen_substrs,
        )?;
    }

    if let Some(noir_file_path) = noir_file_path {
        gen_noir_fn(regex_and_dfa, &PathBuf::from(noir_file_path), gen_substrs)?;
    }

    Ok(())
}

/// Generates outputs from a decomposed regex configuration file.
///
/// # Arguments
///
/// * `decomposed_regex_path` - The path to the decomposed regex configuration file.
/// * `halo2_dir_path` - An optional path to the directory for Halo2 output files.
/// * `circom_file_path` - An optional path to the Circom output file.
/// * `circom_template_name` - An optional name for the Circom template.
/// * `gen_substrs` - An optional boolean indicating whether to generate substrings.
///
/// # Returns
///
/// A `Result` indicating success or a `CompilerError`.
pub fn gen_from_decomposed(
    decomposed_regex_path: &str,
    halo2_dir_path: Option<&str>,
    circom_file_path: Option<&str>,
    circom_template_name: Option<&str>,
    noir_file_path: Option<&str>,
    gen_substrs: Option<bool>,
) -> Result<(), CompilerError> {
    let mut decomposed_regex_config: DecomposedRegexConfig =
        serde_json::from_reader(File::open(decomposed_regex_path)?)?;
    let gen_substrs = gen_substrs.unwrap_or(false);

    let regex_and_dfa = get_regex_and_dfa(&mut decomposed_regex_config)?;

    let num_public_parts = decomposed_regex_config
        .parts
        .iter()
        .filter(|part| part.is_public)
        .count();

    generate_outputs(
        &regex_and_dfa,
        halo2_dir_path,
        circom_file_path,
        circom_template_name,
        noir_file_path,
        num_public_parts,
        gen_substrs,
    )?;

    Ok(())
}

/// Generates outputs from a raw regex string and optional substring definitions.
///
/// # Arguments
///
/// * `raw_regex` - The raw regex string.
/// * `substrs_json_path` - An optional path to the JSON file containing substring definitions.
/// * `halo2_dir_path` - An optional path to the directory for Halo2 output files.
/// * `circom_file_path` - An optional path to the Circom output file.
/// * `template_name` - An optional name for the Circom template.
/// * `gen_substrs` - An optional boolean indicating whether to generate substrings.
///
/// # Returns
///
/// A `Result` indicating success or a `CompilerError`.
pub fn gen_from_raw(
    raw_regex: &str,
    substrs_json_path: Option<&str>,
    halo2_dir_path: Option<&str>,
    circom_file_path: Option<&str>,
    template_name: Option<&str>,
    noir_file_path: Option<&str>,
    gen_substrs: Option<bool>,
) -> Result<(), CompilerError> {
    let substrs_defs_json = load_substring_definitions_json(substrs_json_path)?;
    let num_public_parts = substrs_defs_json.transitions.len();

    let regex_and_dfa = create_regex_and_dfa_from_str_and_defs(raw_regex, substrs_defs_json)?;

    let gen_substrs = gen_substrs.unwrap_or(false);

    generate_outputs(
        &regex_and_dfa,
        halo2_dir_path,
        circom_file_path,
        template_name,
        noir_file_path,
        num_public_parts,
        gen_substrs,
    )?;

    Ok(())
}
