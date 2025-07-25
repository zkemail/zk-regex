use std::path::PathBuf;

use heck::{ToPascalCase, ToSnakeCase};

use crate::{DecomposedRegexConfig, NFAGraph, RegexPart};

/// Combines decomposed regex parts into a single pattern string and extracts capture group lengths.
///
/// This function iterates through the `parts` field of a `DecomposedRegexConfig`.
/// It concatenates `RegexPart::Pattern` strings directly. For `RegexPart::PublicPattern`,
/// it wraps the pattern string in parentheses `()` to form a capture group and collects
/// the associated maximum byte length (`max_len`).
///
/// # Arguments
///
/// * `config` - A reference to the `DecomposedRegexConfig` containing the regex parts.
///
/// # Returns
///
/// A tuple `(String, Option<Vec<usize>>)` where:
/// *   The first element is the fully combined regex pattern string.
/// *   The second element is `Some(Vec<usize>)` containing the max byte lengths if any
///     `PublicPattern` parts were present, or `None` otherwise.
pub fn decomposed_to_composed_regex(
    config: &DecomposedRegexConfig,
) -> (String, Option<Vec<usize>>) {
    let mut combined_parts = Vec::new();
    let mut max_bytes: Option<Vec<usize>> = None;

    for part in &config.parts {
        match part {
            RegexPart::Pattern(pattern) => {
                combined_parts.push(pattern.clone());
            }
            RegexPart::PublicPattern((pattern, max_len)) => {
                combined_parts.push(format!("({})", pattern));
                max_bytes.get_or_insert_with(Vec::new).push(*max_len);
            }
        }
    }

    let combined_pattern = combined_parts.join("");

    (combined_pattern, max_bytes)
}

pub fn validate_cli_template_name(name: &str) -> Result<String, String> {
    // Convert to PascalCase to normalize
    let pascal_name = name.to_pascal_case();

    // Verify it's valid PascalCase
    if pascal_name != name {
        return Err("Template name must be in PascalCase (e.g., ThisIsATemplate)".into());
    }

    Ok(name.to_string())
}

pub fn save_outputs(
    nfa: &NFAGraph,
    circom_code: String,
    output_dir: &PathBuf,
    template_name: &str,
    file_extension: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    validate_cli_template_name(template_name)?;

    // Create output directory if it doesn't exist
    std::fs::create_dir_all(output_dir)?;

    let snake_case_name = template_name.to_snake_case();

    // Save circuit file
    let circuit_path = output_dir.join(format!("{}_regex.{}", snake_case_name, file_extension));
    std::fs::write(&circuit_path, circom_code)?;

    // Save graph JSON
    let graph_json = nfa.to_json()?;
    let graph_path = output_dir.join(format!("{}_graph.json", snake_case_name));
    std::fs::write(&graph_path, graph_json)?;

    println!("Generated files:");
    println!("  Circuit: {}", circuit_path.display());
    println!("  Graph: {}", graph_path.display());

    Ok(())
}
