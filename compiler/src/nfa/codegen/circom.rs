//! Circom circuit generation for NFAs.
//!
//! This module handles conversion of NFAs to Circom circuits for zero-knowledge proofs.
//! The generated circuits can verify:
//! - String matching against regex patterns
//! - Capture group extraction
//! - Path traversal through the NFA
//!
//! The circuit components include:
//! - State transition validation
//! - Byte range checks
//! - Capture group tracking
//! - Path length verification
//! - Start/accept state validation

use std::collections::{HashMap, HashSet};

use regex_automata::meta::Regex;
use serde::Serialize;

use crate::nfa::NFAGraph;
use crate::nfa::error::{NFABuildError, NFAResult};

#[derive(Serialize)]
pub struct CircomInputs {
    curr_states: Vec<usize>,
    next_states: Vec<usize>,
    haystack: Vec<u8>,
    capture_group_ids: Option<Vec<usize>>,
    capture_group_starts: Option<Vec<bool>>,
    capture_group_start_indices: Option<Vec<usize>>,
    traversal_path_length: usize,
}

impl NFAGraph {
    /// Generates the core data needed for Circom circuit generation.
    ///
    /// Returns:
    /// - Vector of start states
    /// - Vector of accept states
    /// - Vector of transitions: (from_state, min_byte, max_byte, to_state, capture_info)
    ///
    /// The transitions are compressed into byte ranges for efficiency.
    pub fn generate_circom_data(
        &self,
    ) -> NFAResult<(
        Vec<usize>,
        Vec<usize>,
        Vec<(usize, u8, u8, usize, Option<(usize, bool)>)>,
    )> {
        if self.start_states.is_empty() {
            return Err(NFABuildError::Verification(
                "NFA has no start states".into(),
            ));
        }
        if self.accept_states.is_empty() {
            return Err(NFABuildError::Verification(
                "NFA has no accept states".into(),
            ));
        }

        let start_states = self.start_states.iter().copied().collect();
        let accept_states = self.accept_states.iter().copied().collect();

        let transitions = self.get_transitions_with_capture_info();
        if transitions.is_empty() {
            return Err(NFABuildError::Verification("NFA has no transitions".into()));
        }

        // Group and convert to ranges
        let mut range_transitions = Vec::new();
        let mut grouped: HashMap<(usize, usize, Option<(usize, bool)>), Vec<u8>> = HashMap::new();

        for (src, byte, dst, capture) in transitions {
            if src >= self.nodes.len() || dst >= self.nodes.len() {
                return Err(NFABuildError::InvalidStateId(format!(
                    "State {}->{} out of bounds",
                    src, dst
                )));
            }
            grouped.entry((src, dst, capture)).or_default().push(byte);
        }

        // Convert to ranges
        for ((src, dst, capture), mut bytes) in grouped {
            if bytes.is_empty() {
                continue;
            }

            bytes.sort_unstable();
            let mut start = bytes[0];
            let mut prev = start;

            for &byte in &bytes[1..] {
                if byte != prev + 1 {
                    range_transitions.push((src, start, prev, dst, capture));
                    start = byte;
                }
                prev = byte;
            }
            range_transitions.push((src, start, prev, dst, capture));
        }

        Ok((start_states, accept_states, range_transitions))
    }

    /// Escapes special characters in regex patterns for display in Circom comments.
    /// Handles newlines, quotes, control characters etc.
    fn escape_regex_for_display(pattern: &str) -> String {
        pattern
            .chars()
            .map(|c| match c {
                '\n' => "\\n".to_string(),
                '\r' => "\\r".to_string(),
                '\t' => "\\t".to_string(),
                '\\' => "\\\\".to_string(),
                '\0' => "\\0".to_string(),
                '\'' => "\\'".to_string(),
                '\"' => "\\\"".to_string(),
                '\x08' => "\\b".to_string(),
                '\x0c' => "\\f".to_string(),
                c if c.is_ascii_control() => format!("\\x{:02x}", c as u8),
                c => c.to_string(),
            })
            .collect()
    }

    /// Generates complete Circom circuit code for the NFA.
    ///
    /// # Arguments
    /// * `regex_name` - Name of the regex template
    /// * `regex_pattern` - Original regex pattern (for documentation)
    /// * `max_substring_bytes` - Maximum lengths for capture group substrings
    ///
    /// # Generated Circuit Features
    /// - Input validation for state transitions
    /// - Byte range checking
    /// - Capture group extraction
    /// - Path length verification
    /// - Start/accept state validation
    ///
    /// # Example Circuit Structure
    /// ```circom
    /// template MyRegex(maxBytes) {
    ///     signal input currStates[maxBytes];
    ///     signal input haystack[maxBytes];
    ///     signal input nextStates[maxBytes];
    ///     // ... capture signals if needed ...
    ///
    ///     // State transition validation
    ///     // Byte range checks
    ///     // Path verification
    /// }
    /// ```
    pub fn generate_circom_code(
        &self,
        regex_name: &str,
        regex_pattern: &str,
        max_substring_bytes: Option<&[usize]>,
    ) -> NFAResult<String> {
        if regex_name.is_empty() {
            return Err(NFABuildError::Build("Empty regex name".into()));
        }

        let (start_states, accept_states, transitions) = self.generate_circom_data()?;

        // Validate capture groups
        let capture_group_set: HashSet<_> = transitions
            .iter()
            .filter_map(|(_, _, _, _, cap)| cap.map(|(id, _)| id))
            .collect();

        if !capture_group_set.is_empty() {
            if let Some(max_bytes) = max_substring_bytes {
                if max_bytes.len() < capture_group_set.len() {
                    return Err(NFABuildError::InvalidCapture(format!(
                        "Insufficient max_substring_bytes: need {} but got {}",
                        capture_group_set.len(),
                        max_bytes.len()
                    )));
                }
                for &bytes in max_bytes {
                    if bytes == 0 {
                        return Err(NFABuildError::InvalidCapture(
                            "max_substring_bytes contains zero length".into(),
                        ));
                    }
                }
            } else {
                return Err(NFABuildError::InvalidCapture(
                    "max_substring_bytes required for capture groups".into(),
                ));
            }
        }

        let has_capture_groups = !capture_group_set.is_empty();

        let mut code = String::new();

        code.push_str("pragma circom 2.1.5;\n\n");

        code.push_str("include \"circomlib/comparators.circom\";\n");
        code.push_str("include \"circomlib/gates.circom\";\n");
        code.push_str("include \"@zk-email/zk-regex-circom/circuits/regex_helpers.circom\";\n\n");

        let display_pattern = Self::escape_regex_for_display(regex_pattern);
        code.push_str(format!("// regex: {}\n", display_pattern).as_str());
        code.push_str(format!("template {}Regex(maxBytes) {{\n", regex_name).as_str());

        code.push_str("    signal input currStates[maxBytes];\n");
        code.push_str("    signal input haystack[maxBytes];\n");
        code.push_str("    signal input nextStates[maxBytes];\n");

        // Only add capture group signals if needed
        if has_capture_groups {
            code.push_str("    signal input captureGroupIds[maxBytes];\n");
            code.push_str("    signal input captureGroupStarts[maxBytes];\n");
        }

        code.push_str("    signal input traversalPathLength;\n\n");

        code.push_str(format!("    var numStartStates = {};\n", start_states.len()).as_str());
        code.push_str(format!("    var numAcceptStates = {};\n", accept_states.len()).as_str());
        code.push_str(format!("    var numTransitions = {};\n", transitions.len()).as_str());
        code.push_str(
            format!(
                "    var startStates[numStartStates] = [{}];\n",
                start_states
                    .iter()
                    .map(|s| s.to_string())
                    .collect::<Vec<String>>()
                    .join(", ")
            )
            .as_str(),
        );
        code.push_str(
            format!(
                "    var acceptStates[numAcceptStates] = [{}];\n\n",
                accept_states
                    .iter()
                    .map(|s| s.to_string())
                    .collect::<Vec<String>>()
                    .join(", ")
            )
            .as_str(),
        );

        code.push_str("    signal isCurrentState[numTransitions][maxBytes];\n");
        code.push_str("    signal isNextState[numTransitions][maxBytes];\n");
        code.push_str("    signal isValidTransition[numTransitions][maxBytes];\n");
        code.push_str("    signal reachedLastTransition[maxBytes];\n");
        code.push_str("    signal isValidRegex[maxBytes];\n");
        code.push_str("    signal isValidRegexTemp[maxBytes];\n");
        code.push_str("    signal isWithinPathLength[maxBytes];\n");
        code.push_str("    signal isTransitionLinked[maxBytes];\n");

        if start_states.len() > 1 {
            code.push_str("\n    component isValidStartState;\n");
        } else {
            code.push_str("\n    signal isValidStartState;\n");
        }

        if accept_states.len() > 1 {
            code.push_str("\n    component reachedAcceptState[maxBytes];\n");
        } else {
            code.push_str("\n    signal reachedAcceptState[maxBytes];\n");
        }

        code.push_str("\n    component isValidTraversal[maxBytes];\n\n");

        code.push_str("    // Check if the first state in the haystack is a valid start state\n");
        if start_states.len() > 1 {
            code.push_str("    isValidStartState = MultiOR(numStartStates);\n");
            code.push_str("    for (var i = 0; i < numStartStates; i++) {\n");
            code.push_str(
                "        isValidStartState.in[i] <== IsEqual()([startStates[i], currStates[0]]);\n",
            );
            code.push_str("    }\n");
            code.push_str("    isValidStartState.out === 1;\n\n");
        } else {
            code.push_str(
                "    isValidStartState <== IsEqual()([startStates[0], currStates[0]]);\n\n",
            );
        }

        code.push_str("    for (var i = 0; i < maxBytes; i++) {\n");
        code.push_str(
            "        isWithinPathLength[i] <== LessThan(log2Ceil(maxBytes))([i, traversalPathLength]);\n\n"
        );

        code.push_str("        // Check if the traversal is a valid path\n");
        code.push_str(
            "        isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);\n",
        );
        code.push_str("        isTransitionLinked[i] === isWithinPathLength[i];\n\n");

        if has_capture_groups {
            for (transition_idx, (curr_state, start, end, next_state, capture_info)) in
                transitions.iter().enumerate()
            {
                let (capture_group_id, capture_group_start) = match capture_info {
                    Some(capture_info) => (capture_info.0, capture_info.1 as u8),
                    None => (0, 0),
                };

                if start == end {
                    code.push_str(
                        format!(
                            "        // Transition {}: {} -[{}]-> {} | Capture Group: ({}, {})\n",
                            transition_idx,
                            curr_state,
                            start,
                            next_state,
                            capture_group_id,
                            capture_group_start
                        )
                        .as_str(),
                    );
                    code.push_str(
                        format!(
                            "        isValidTransition[{}][i] <== CheckByteTransitionWithCapture()({}, {}, {}, {}, {}, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);\n",
                            transition_idx,
                            curr_state,
                            next_state,
                            start,
                            capture_group_id,
                            capture_group_start
                        ).as_str()
                    );
                } else {
                    code.push_str(
                        format!(
                            "        // Transition {}: {} -[{}-{}]-> {} | Capture Group: ({}, {})\n",
                            transition_idx,
                            curr_state,
                            start,
                            end,
                            next_state,
                            capture_group_id,
                            capture_group_start
                        ).as_str()
                    );
                    code.push_str(
                        format!(
                            "        isValidTransition[{}][i] <== CheckByteRangeTransitionWithCapture()({}, {}, {}, {}, {}, {}, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);\n",
                            transition_idx,
                            curr_state,
                            next_state,
                            start,
                            end,
                            capture_group_id,
                            capture_group_start
                        ).as_str()
                    );
                }
            }
        } else {
            for (transition_idx, (curr_state, start, end, next_state, _)) in
                transitions.iter().enumerate()
            {
                if start == end {
                    code.push_str(
                        format!(
                            "        // Transition {}: {} -[{}]-> {}\n",
                            transition_idx, curr_state, start, next_state
                        )
                        .as_str(),
                    );
                    code.push_str(
                        format!(
                            "        isValidTransition[{}][i] <== CheckByteTransition()({}, {}, {}, currStates[i], nextStates[i], haystack[i]);\n",
                            transition_idx,
                            curr_state,
                            next_state,
                            start
                        ).as_str()
                    );
                } else {
                    code.push_str(
                        format!(
                            "        // Transition {}: {} -[{}-{}]-> {}\n",
                            transition_idx, curr_state, start, end, next_state
                        )
                        .as_str(),
                    );
                    code.push_str(
                        format!(
                            "        isValidTransition[{}][i] <== CheckByteRangeTransition()({}, {}, {}, {}, currStates[i], nextStates[i], haystack[i]);\n",
                            transition_idx,
                            curr_state,
                            next_state,
                            start,
                            end
                        ).as_str()
                    );
                }
            }
        }

        code.push_str("\n        // Combine all valid transitions for this byte\n");
        code.push_str("        isValidTraversal[i] = MultiOR(numTransitions);\n");
        code.push_str("        for (var j = 0; j < numTransitions; j++) {\n");
        code.push_str("            isValidTraversal[i].in[j] <== isValidTransition[j][i];\n");
        code.push_str("        }\n");
        code.push_str("        isValidTraversal[i].out === isWithinPathLength[i];\n\n");

        code.push_str(
            "        // Check if any accept state has been reached at the last transition\n",
        );
        code.push_str(
            "        reachedLastTransition[i] <== IsEqual()([i, traversalPathLength-1]);\n",
        );

        if accept_states.len() > 1 {
            code.push_str("        reachedAcceptState[i] = MultiOR(numAcceptStates);\n");
            code.push_str("        for (var j = 0; j < numAcceptStates; j++) {\n");
            code.push_str(
                "            reachedAcceptState[i].in[j] <== IsEqual()([nextStates[i], acceptStates[j]]);\n"
            );
            code.push_str("        }\n");
            code.push_str("        reachedAcceptState[i].out === 1;\n");
            code.push_str(
                "        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i].out);\n"
            );
        } else {
            code.push_str(
                "        reachedAcceptState[i] <== IsEqual()([nextStates[i], acceptStates[0]]);\n",
            );
            code.push_str(
                "        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i]);\n"
            );
        }

        code.push_str("        if (i == 0) {\n");
        code.push_str("            isValidRegex[i] <== isValidRegexTemp[i];\n");
        code.push_str("        } else {\n");
        code.push_str("            isValidRegex[i] <== isValidRegexTemp[i] + isValidRegex[i-1];\n");
        code.push_str("        }\n");
        code.push_str("    }\n");
        code.push_str("    isValidRegex[maxBytes-1] === 1;\n\n");

        if has_capture_groups {
            for capture_group_id in capture_group_set {
                let max_substring_bytes = if let Some(max_substring_bytes) = max_substring_bytes {
                    max_substring_bytes[capture_group_id - 1]
                } else {
                    return Err(NFABuildError::InvalidCapture(format!(
                        "Max substring bytes not provided for capture group {}",
                        capture_group_id
                    )));
                };

                code.push_str(format!("    // Capture Group {}\n", capture_group_id).as_str());
                code.push_str(
                    format!("    signal input capture{}StartIndex;\n", capture_group_id).as_str(),
                );
                code.push_str(
                    format!(
                        "    signal output capture{}[{}] <== CaptureSubstring(maxBytes, {}, {})(capture{}StartIndex, haystack, captureGroupIds, captureGroupStarts);\n",
                        capture_group_id,
                        max_substring_bytes,
                        max_substring_bytes,
                        capture_group_id,
                        capture_group_id
                    ).as_str()
                );
            }
        }

        code.push_str("}\n");

        Ok(code)
    }

    pub fn generate_circom_inputs(
        &self,
        haystack: &str,
        max_haystack_len: usize,
    ) -> NFAResult<CircomInputs> {
        let haystack_bytes = haystack.as_bytes();

        if haystack_bytes.len() > max_haystack_len {
            return Err(NFABuildError::Build(format!(
                "Haystack length {} exceeds maximum length {}",
                haystack_bytes.len(),
                max_haystack_len
            )));
        }

        // Generate path traversal
        let path = self.generate_path_traversal(haystack_bytes)?;
        let path_len = path.len();

        // Extract and pad arrays to max_haystack_len
        let mut curr_states = path.iter().map(|(curr, _, _, _)| *curr).collect::<Vec<_>>();
        let mut next_states = path.iter().map(|(_, next, _, _)| *next).collect::<Vec<_>>();
        let mut haystack = haystack_bytes.to_vec();

        // Pad with zeros
        curr_states.resize(max_haystack_len, 136279841);
        next_states.resize(max_haystack_len, 136279842);
        haystack.resize(max_haystack_len, 0);

        // Handle capture groups if they exist
        let (capture_group_ids, capture_group_starts, capture_group_start_indices) =
            if path.iter().any(|(_, _, _, c)| c.is_some()) {
                let mut ids = path
                    .iter()
                    .map(|(_, _, _, c)| c.map(|(id, _)| id).unwrap_or(0))
                    .collect::<Vec<_>>();
                let mut starts = path
                    .iter()
                    .map(|(_, _, _, c)| c.map(|(_, start)| start).unwrap_or(false))
                    .collect::<Vec<_>>();

                // Use regex_automata to get capture start indices
                let re = Regex::new(&self.regex)
                    .map_err(|e| NFABuildError::Build(format!("Failed to compile regex: {}", e)))?;
                let mut captures = re.create_captures();
                re.captures(&haystack, &mut captures);

                let start_indices = (1..=captures.group_len())
                    .filter_map(|i| captures.get_group(i))
                    .map(|m| m.start)
                    .collect();

                // Pad arrays
                ids.resize(max_haystack_len, 0);
                starts.resize(max_haystack_len, false);

                (Some(ids), Some(starts), Some(start_indices))
            } else {
                (None, None, None)
            };

        Ok(CircomInputs {
            curr_states,
            next_states,
            haystack,
            capture_group_ids,
            capture_group_starts,
            capture_group_start_indices,
            traversal_path_length: path_len,
        })
    }
}
