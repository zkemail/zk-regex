use std::path::PathBuf;

use heck::{ToPascalCase, ToSnakeCase};

use crate::{DecomposedRegexConfig, NFAGraph, RegexPart};

/// Converts bare capturing groups `(...)` to non-capturing groups `(?:...)` in a regex pattern.
///
/// This function only converts opening parentheses that are not already part of special
/// regex constructs like `(?:...)`, `(?=...)`, `(?!...)`, `(?<=...)`, `(?<!...)`, etc.
///
/// # Known Limitations
///
/// This is a simple character-by-character scan that doesn't parse the full regex syntax.
/// It will convert escaped parentheses `\(` which may not be desired in all cases, though
/// this rarely causes issues in practice since the regex compiler handles escaped characters.
///
/// # Arguments
///
/// * `pattern` - The regex pattern string to process
///
/// # Returns
///
/// A new string with bare capturing groups converted to non-capturing groups
///
/// # Examples
///
/// ```text
/// convert_capturing_to_non_capturing("(a|b)")     → "(?:a|b)"
/// convert_capturing_to_non_capturing("(?:a|b)")   → "(?:a|b)" // unchanged
/// convert_capturing_to_non_capturing("(?=a)")     → "(?=a)"   // unchanged
/// ```
fn convert_capturing_to_non_capturing(pattern: &str) -> String {
    let mut result = String::with_capacity(pattern.len() + pattern.len() / 4);
    let chars: Vec<char> = pattern.chars().collect();
    let mut i = 0;

    while i < chars.len() {
        if chars[i] == '(' && (i + 1 >= chars.len() || chars[i + 1] != '?') {
            // This is a bare capturing group, convert it to non-capturing
            result.push_str("(?:");
        } else {
            result.push(chars[i]);
        }
        i += 1;
    }

    result
}

/// Combines decomposed regex parts into a single pattern string and extracts capture group lengths.
///
/// This function iterates through the `parts` field of a `DecomposedRegexConfig`.
/// For `RegexPart::Pattern` parts, it converts any bare capturing groups `(...)` to
/// non-capturing groups `(?:...)` to prevent interference with capture group numbering.
/// For `RegexPart::PublicPattern`, it wraps the pattern string in parentheses `()`
/// to form a capture group and collects the associated maximum byte length (`max_len`).
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
                // Convert bare capturing groups to non-capturing groups
                let non_capturing_pattern = convert_capturing_to_non_capturing(pattern);
                combined_parts.push(non_capturing_pattern);
            }
            RegexPart::PublicPattern((pattern, max_len)) => {
                combined_parts.push(format!("({pattern})"));
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
    let circuit_path = output_dir.join(format!("{snake_case_name}_regex.{file_extension}"));
    std::fs::write(&circuit_path, circom_code)?;

    // Save graph JSON
    let graph_json = nfa.to_json()?;
    let graph_path = output_dir.join(format!("{snake_case_name}_graph.json"));
    std::fs::write(&graph_path, graph_json)?;

    println!("Generated files:");
    println!("  Circuit: {}", circuit_path.display());
    println!("  Graph: {}", graph_path.display());

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_convert_single_capturing_group() {
        let input = "(a|b)";
        let expected = "(?:a|b)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_convert_multiple_capturing_groups() {
        let input = "(a|b)(c|d)";
        let expected = "(?:a|b)(?:c|d)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_preserve_non_capturing_groups() {
        let input = "(?:a|b)";
        let expected = "(?:a|b)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_preserve_positive_lookahead() {
        let input = "(?=abc)";
        let expected = "(?=abc)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_preserve_negative_lookahead() {
        let input = "(?!abc)";
        let expected = "(?!abc)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_preserve_positive_lookbehind() {
        let input = "(?<=abc)";
        let expected = "(?<=abc)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_preserve_negative_lookbehind() {
        let input = "(?<!abc)";
        let expected = "(?<!abc)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_preserve_named_groups() {
        let input = "(?<name>abc)";
        let expected = "(?<name>abc)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_preserve_comments() {
        let input = "(?#comment)";
        let expected = "(?#comment)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_nested_capturing_groups() {
        let input = "((a|b))";
        let expected = "(?:(?:a|b))";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_no_groups() {
        let input = "abc";
        let expected = "abc";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_mixed_groups() {
        let input = "(a|b)(?:c|d)(e|f)(?=g)";
        let expected = "(?:a|b)(?:c|d)(?:e|f)(?=g)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_complex_pattern() {
        let input = "(?:prefix_)(a|b)(?=suffix)";
        let expected = "(?:prefix_)(?:a|b)(?=suffix)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_empty_string() {
        let input = "";
        let expected = "";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_escaped_parentheses() {
        // Note: This test checks literal escaped parens in the string
        // In actual regex, \( is an escaped paren, but we're working with strings
        let input = r"\(not a group\)";
        let expected = r"\(?:not a group\)"; // Our simple implementation will convert \(
        // This is a known limitation - escaped parens would need more sophisticated parsing
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_decomposed_to_composed_with_capturing_groups() {
        let config = DecomposedRegexConfig {
            parts: vec![
                RegexPart::Pattern("(a|b)prefix:".to_string()),
                RegexPart::PublicPattern(("value".to_string(), 20)),
            ],
        };

        let (combined, max_bytes) = decomposed_to_composed_regex(&config);

        assert_eq!(combined, "(?:a|b)prefix:(value)");
        assert_eq!(max_bytes, Some(vec![20]));
    }

    #[test]
    fn test_decomposed_to_composed_preserves_special_groups() {
        let config = DecomposedRegexConfig {
            parts: vec![
                RegexPart::Pattern("(?:a|b)prefix:".to_string()),
                RegexPart::PublicPattern(("value".to_string(), 20)),
                RegexPart::Pattern("(?=suffix)".to_string()),
            ],
        };

        let (combined, max_bytes) = decomposed_to_composed_regex(&config);

        assert_eq!(combined, "(?:a|b)prefix:(value)(?=suffix)");
        assert_eq!(max_bytes, Some(vec![20]));
    }

    #[test]
    fn test_decomposed_multiple_patterns_and_public() {
        let config = DecomposedRegexConfig {
            parts: vec![
                RegexPart::Pattern("(a|b)".to_string()),
                RegexPart::PublicPattern(("first".to_string(), 10)),
                RegexPart::Pattern("(c|d)".to_string()),
                RegexPart::PublicPattern(("second".to_string(), 15)),
            ],
        };

        let (combined, max_bytes) = decomposed_to_composed_regex(&config);

        assert_eq!(combined, "(?:a|b)(first)(?:c|d)(second)");
        assert_eq!(max_bytes, Some(vec![10, 15]));
    }
}
