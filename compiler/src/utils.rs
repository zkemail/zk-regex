use crate::{DecomposedRegexConfig, RegexPart};

pub fn decomposed_to_composed_regex(config: &DecomposedRegexConfig) -> (String, Vec<usize>) {
    let mut combined_parts = Vec::new();
    let mut max_bytes = Vec::new();

    for part in &config.parts {
        match part {
            RegexPart::Pattern(pattern) => {
                combined_parts.push(pattern.clone());
            }
            RegexPart::PublicPattern((pattern, max_len)) => {
                combined_parts.push(format!("({})", pattern));
                max_bytes.push(*max_len);
            }
        }
    }

    let combined_pattern = combined_parts.join("");

    (combined_pattern, max_bytes)
}
