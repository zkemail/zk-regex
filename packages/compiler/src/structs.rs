use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet, VecDeque};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegexPartConfig {
    pub is_public: bool,
    pub regex_def: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecomposedRegexConfig {
    pub parts: VecDeque<RegexPartConfig>,
}

#[derive(Debug, Clone)]
pub struct DFAStateInfo {
    pub typ: String,
    pub source: usize,
    pub edges: BTreeMap<String, usize>,
}

#[derive(Debug)]
pub struct DFAGraphInfo {
    pub states: Vec<DFAStateInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DFAStateNode {
    pub state_type: String,
    pub state_id: usize,
    pub transitions: BTreeMap<usize, BTreeSet<u8>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DFAGraph {
    pub states: Vec<DFAStateNode>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstringDefinitions {
    pub substring_ranges: Vec<BTreeSet<(usize, usize)>>,
    pub substring_boundaries: Option<Vec<(BTreeSet<usize>, BTreeSet<usize>)>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegexAndDFA {
    pub regex_pattern: String,
    pub dfa: DFAGraph,
    pub has_end_anchor: bool,
    pub substrings: SubstringDefinitions,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstringDefinitionsJson {
    pub transitions: Vec<Vec<(usize, usize)>>,
}

impl std::fmt::Display for DFAStateNode {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        let state_type = match self.state_type.as_str() {
            "start" => "START",
            "accept" => "ACCEPT",
            _ => "NORMAL",
        };

        writeln!(f, "State {} ({})", self.state_id, state_type)?;

        for (dest, chars) in &self.transitions {
            let mut ranges = Vec::new();
            let mut current_range: Option<(u8, u8)> = None;
            let mut sorted_chars: Vec<u8> = chars.iter().copied().collect();
            sorted_chars.sort_unstable();

            for &b in &sorted_chars {
                match current_range {
                    Some((start, end)) if b == end + 1 => current_range = Some((start, b)),
                    Some((start, end)) => {
                        ranges.push((start, end));
                        current_range = Some((b, b));
                    }
                    None => current_range = Some((b, b)),
                }
            }
            if let Some(range) = current_range {
                ranges.push(range);
            }

            let transitions: Vec<String> = ranges
                .iter()
                .map(|(start, end)| {
                    let start_char = byte_to_char(*start);
                    let end_char = byte_to_char(*end);
                    if start == end {
                        start_char
                    } else {
                        format!("{}-{}", start_char, end_char)
                    }
                })
                .collect();

            writeln!(f, "└── [{}] → State {}", transitions.join(", "), dest)?;
        }

        Ok(())
    }
}

impl std::fmt::Display for DFAGraph {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        for state in &self.states {
            write!(f, "{}", state)?;
            writeln!(f, "{}", "-".repeat(50))?;
        }
        Ok(())
    }
}

fn byte_to_char(b: u8) -> String {
    match b {
        0x09 => "\\t".into(),
        0x0A => "\\n".into(),
        0x0D => "\\r".into(),
        0x20 => "␣".into(),
        0x21..=0x7E => format!("{}", b as char),
        _ => format!("0x{:02X}", b),
    }
}

pub struct ReverseDFAStateNode {
    pub state_id: usize,
    pub transitions: BTreeMap<usize, BTreeSet<u8>>, // Map of source state to transition chars
    pub state_type: String,
}

impl std::fmt::Display for ReverseDFAStateNode {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        let state_type = match self.state_type.as_str() {
            "start" => "REVERSE START",
            "accept" => "REVERSE ACCEPT",
            _ => "REVERSE",
        };

        writeln!(f, "State {} ({})", self.state_id, state_type)?;

        // Group transitions by source state
        let mut grouped: BTreeMap<usize, Vec<u8>> = BTreeMap::new();
        for (src, chars) in &self.transitions {
            grouped.insert(*src, chars.iter().copied().collect());
        }

        // Format each source state's transitions
        for (src, chars) in grouped {
            let mut ranges = Vec::new();
            let mut current_range: Option<(u8, u8)> = None;
            let mut sorted_chars: Vec<u8> = chars;
            sorted_chars.sort_unstable();

            for b in sorted_chars {
                match current_range {
                    Some((start, end)) if b == end + 1 => current_range = Some((start, b)),
                    Some((start, end)) => {
                        ranges.push((start, end));
                        current_range = Some((b, b));
                    }
                    None => current_range = Some((b, b)),
                }
            }
            if let Some(range) = current_range {
                ranges.push(range);
            }

            let transitions: Vec<String> = ranges
                .iter()
                .map(|(start, end)| {
                    let start_char = byte_to_char(*start);
                    let end_char = byte_to_char(*end);
                    if start == end {
                        start_char
                    } else {
                        format!("{}-{}", start_char, end_char)
                    }
                })
                .collect();

            writeln!(f, "└── ← via [{}] ← State {}", transitions.join(", "), src)?;
        }

        Ok(())
    }
}

pub struct ReverseDFAGraph {
    pub states: Vec<ReverseDFAStateNode>,
}

impl std::fmt::Display for ReverseDFAGraph {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        for state in &self.states {
            write!(f, "{}", state)?;
            writeln!(f, "{}", "-".repeat(50))?;
        }
        Ok(())
    }
}
