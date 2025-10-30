use std::path::PathBuf;

use heck::{ToPascalCase, ToSnakeCase};

use crate::{DecomposedRegexConfig, NFAGraph, RegexPart};

/// Converts bare capturing groups `(...)` to non-capturing groups `(?:...)` in a regex pattern.
///
/// This function properly handles:
/// - Escaped parentheses like `\(` and `\)` (preserved as-is)
/// - Parentheses within character classes like `[()]` (preserved as-is)
/// - Special groups like `(?:...)`, `(?=...)`, `(?!...)`, etc. (preserved as-is)
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
/// convert_capturing_to_non_capturing(r"\(a\)")    → r"\(a\)"  // escaped parens preserved
/// convert_capturing_to_non_capturing("[()]")      → "[()]"    // char class preserved
/// ```
fn convert_capturing_to_non_capturing(pattern: &str) -> String {
    let mut result = String::with_capacity(pattern.len() + pattern.len() / 4);
    let chars: Vec<char> = pattern.chars().collect();
    let mut i = 0;
    let mut in_char_class = false;
    let mut escaped = false;

    while i < chars.len() {
        let ch = chars[i];

        if escaped {
            // Previous char was backslash, this char is escaped
            result.push(ch);
            escaped = false;
        } else if ch == '\\' {
            // Start escape sequence
            result.push(ch);
            escaped = true;
        } else if ch == '[' && !in_char_class {
            // Entering character class
            result.push(ch);
            in_char_class = true;
        } else if ch == ']' && in_char_class {
            // Exiting character class
            result.push(ch);
            in_char_class = false;
        } else if ch == '(' && !in_char_class {
            // Check if this is a bare capturing group
            if i + 1 >= chars.len() || chars[i + 1] != '?' {
                // This is a bare capturing group, convert it to non-capturing
                result.push_str("(?:");
            } else {
                // This is already a special group (?...), keep as-is
                result.push(ch);
            }
        } else {
            result.push(ch);
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
        // Escaped parentheses should be preserved as-is (they match literal parens)
        let input = r"\(not a group\)";
        let expected = r"\(not a group\)";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_character_class_with_parentheses() {
        // Parentheses inside character classes should be preserved
        let input = "[()]";
        let expected = "[()]";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_character_class_complex() {
        // Complex pattern with character class containing parens
        let input = "before[()]after";
        let expected = "before[()]after";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_mixed_escaped_and_capturing() {
        // Mix of escaped parens, character classes, and capturing groups
        let input = r"\((a|b)[()]";
        let expected = r"\((?:a|b)[()]";
        assert_eq!(convert_capturing_to_non_capturing(input), expected);
    }

    #[test]
    fn test_nested_character_classes() {
        // Character class followed by capturing group
        let input = "[()]{2}(abc)";
        let expected = "[()]{2}(?:abc)";
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

    /// This test verifies that capturing groups in Pattern parts are automatically
    /// converted to non-capturing groups, preventing interference with PublicPattern
    /// capture group numbering.
    #[test]
    fn test_wrap_capture_group_into_non_capturing_group_in_private_pattern() {
        use crate::{gen_from_decomposed, ProvingFramework};

        // This is the pattern that contains a private capture group that should be wrapped into a non-capturing group
        let regex_with_private_capture_group = DecomposedRegexConfig {
            parts: vec![
                // Pattern with capturing group - should be converted to non-capturing
                RegexPart::Pattern("(a|b)prefix:".to_string()),
                // This should be capture group 1 for the circuit
                RegexPart::PublicPattern((".+?".to_string(), 20)),
            ],
        };

        let (nfa, _circuit_code) = gen_from_decomposed(
            regex_with_private_capture_group,
            "TestCapture1",
            ProvingFramework::Circom,
        )
        .expect("Should compile successfully");

        assert_eq!(nfa.regex, "(?:a|b)prefix:(.+?)");
        assert_eq!(nfa.num_capture_groups, 1);
    }
}
