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
use serde::Serialize;

use crate::nfa::NFAGraph;
use crate::nfa::error::{NFAError, NFAResult};
use crate::nfa::codegen::CircuitInputs;

#[derive(Serialize)]
pub struct CircomInputs {
    #[serde(rename = "inHaystack")]
    in_haystack: Vec<u8>,
    #[serde(rename = "matchStart")]
    match_start: usize,
    #[serde(rename = "matchLength")]
    match_length: usize,
    #[serde(rename = "currStates")]
    curr_states: Vec<usize>,
    #[serde(rename = "nextStates")]
    next_states: Vec<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "captureGroupIds")]
    capture_group_ids: Option<Vec<usize>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "captureGroupStarts")]
    capture_group_starts: Option<Vec<u8>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "captureGroupStartIndices")]
    capture_group_start_indices: Option<Vec<usize>>,
    #[serde(rename = "traversalPathLength")]
    traversal_path_length: usize,
}

impl From<CircuitInputs> for CircomInputs {
    fn from(inputs: CircuitInputs) -> Self {
        CircomInputs {
            in_haystack: inputs.in_haystack,
            match_start: inputs.match_start,
            match_length: inputs.match_length,
            curr_states: inputs.curr_states,
            next_states: inputs.next_states,
            capture_group_ids: inputs.capture_group_ids,
            capture_group_starts: inputs.capture_group_starts,
            capture_group_start_indices: inputs.capture_group_start_indices,
            traversal_path_length: inputs.traversal_path_length,
        }
    }
}

impl NFAGraph {
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
    pub fn generate_circom_code(
        &self,
        regex_name: &str,
        regex_pattern: &str,
        max_substring_bytes: Option<&[usize]>,
    ) -> NFAResult<String> {
        if regex_name.is_empty() {
            return Err(NFAError::InvalidInput("Empty regex name".into()));
        }

        let (start_states, accept_states, transitions) = self.generate_circuit_data()?;

        // Validate capture groups
        let capture_group_set: HashSet<_> = transitions
            .iter()
            .filter_map(|(_, _, _, _, cap)| cap.map(|(id, _)| id))
            .collect();

        if !capture_group_set.is_empty() {
            if let Some(max_bytes) = max_substring_bytes {
                if max_bytes.len() < capture_group_set.len() {
                    return Err(NFAError::InvalidCapture(format!(
                        "Insufficient max_substring_bytes: need {} but got {}",
                        capture_group_set.len(),
                        max_bytes.len()
                    )));
                }
                for &bytes in max_bytes {
                    if bytes == 0 {
                        return Err(NFAError::InvalidCapture(
                            "max_substring_bytes contains zero length".into(),
                        ));
                    }
                }
            } else {
                return Err(NFAError::InvalidCapture(
                    "max_substring_bytes required for capture groups".into(),
                ));
            }
        }

        let has_capture_groups = !capture_group_set.is_empty();

        let mut code = String::new();

        code.push_str("pragma circom 2.1.5;\n\n");

        code.push_str("include \"circomlib/circuits/comparators.circom\";\n");
        code.push_str("include \"circomlib/circuits/gates.circom\";\n");
        code.push_str("include \"@zk-email/zk-regex-circom/circuits/regex_helpers.circom\";\n");
        code.push_str("include \"@zk-email/circuits/utils/array.circom\";\n\n");

        let display_pattern = Self::escape_regex_for_display(regex_pattern);
        code.push_str(format!("// regex: {}\n", display_pattern).as_str());
        code.push_str(
            format!(
                "template {}Regex(maxHaystackBytes, maxMatchBytes) {{\n",
                regex_name
            )
            .as_str(),
        );

        code.push_str("    signal input inHaystack[maxHaystackBytes];\n");
        code.push_str("    signal input matchStart;\n");
        code.push_str("    signal input matchLength;\n\n");

        code.push_str("    signal input currStates[maxMatchBytes];\n");
        code.push_str("    signal input nextStates[maxMatchBytes];\n");

        // Only add capture group signals if needed
        if has_capture_groups {
            code.push_str("    signal input captureGroupIds[maxMatchBytes];\n");
            code.push_str("    signal input captureGroupStarts[maxMatchBytes];\n\n");
        }

        code.push_str("    signal output isValid;\n\n");

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

        code.push_str("    signal isCurrentState[numTransitions][maxMatchBytes];\n");
        code.push_str("    signal isNextState[numTransitions][maxMatchBytes];\n");
        code.push_str("    signal isValidTransition[numTransitions][maxMatchBytes];\n");
        code.push_str("    signal reachedLastTransition[maxMatchBytes];\n");
        code.push_str("    signal isValidRegex[maxMatchBytes];\n");
        code.push_str("    signal isValidRegexTemp[maxMatchBytes];\n");
        code.push_str("    signal isWithinPathLength[maxMatchBytes];\n");
        code.push_str("    signal isWithinPathLengthMinusOne[maxMatchBytes-2];\n");
        code.push_str("    signal isTransitionLinked[maxMatchBytes];\n");

        if start_states.len() > 1 {
            code.push_str("\n    component isValidStartState;\n");
        } else {
            code.push_str("\n    signal isValidStartState;\n");
        }

        if accept_states.len() > 1 {
            code.push_str("\n    component reachedAcceptState[maxMatchBytes];\n");
        } else {
            code.push_str("\n    signal reachedAcceptState[maxMatchBytes];\n");
        }

        code.push_str("\n    component isValidTraversal[maxMatchBytes];\n\n");

        code.push_str("    // Select the haystack from the input\n");
        code.push_str(
            "    signal haystack[maxMatchBytes] <== SelectSubArray(maxHaystackBytes, maxMatchBytes)(inHaystack, matchStart, matchLength);\n\n"
        );

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

        code.push_str("    for (var i = 0; i < maxMatchBytes; i++) {\n");
        code.push_str(
            "        isWithinPathLength[i] <== LessThan(log2Ceil(maxMatchBytes))([i, matchLength]);\n\n"
        );

        code.push_str("        // Check if the traversal is a valid path\n");
        code.push_str("        if (i < maxMatchBytes-2) {\n");
        code.push_str(
            "            isWithinPathLengthMinusOne[i] <== LessThan(log2Ceil(maxMatchBytes))([i, matchLength-1]);\n"
        );
        code.push_str(
            "            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);\n",
        );
        code.push_str("            isTransitionLinked[i] === isWithinPathLengthMinusOne[i];\n");
        code.push_str("        }\n\n");

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
        code.push_str("        reachedLastTransition[i] <== IsEqual()([i, matchLength-1]);\n");

        if accept_states.len() > 1 {
            code.push_str("        reachedAcceptState[i] = MultiOR(numAcceptStates);\n");
            code.push_str("        for (var j = 0; j < numAcceptStates; j++) {\n");
            code.push_str(
                "            reachedAcceptState[i].in[j] <== IsEqual()([nextStates[i], acceptStates[j]]);\n"
            );
            code.push_str("        }\n");
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
        code.push_str("    }\n\n");
        code.push_str("    isValid <== isValidRegex[maxMatchBytes-1];\n\n");

        if has_capture_groups {
            code.push_str(
                format!(
                    "    signal input captureGroupStartIndices[{}];\n\n",
                    capture_group_set.len()
                )
                .as_str(),
            );
            for capture_group_id in capture_group_set {
                let max_substring_bytes = if let Some(max_substring_bytes) = max_substring_bytes {
                    max_substring_bytes[capture_group_id - 1]
                } else {
                    return Err(NFAError::InvalidCapture(format!(
                        "Max substring bytes not provided for capture group {}",
                        capture_group_id
                    )));
                };

                code.push_str(format!("    // Capture Group {}\n", capture_group_id).as_str());
                code.push_str(
                    format!(
                        "    signal output capture{}[{}] <== CaptureSubstring(maxMatchBytes, {}, {})(captureGroupStartIndices[{}], haystack, captureGroupIds, captureGroupStarts);\n",
                        capture_group_id,
                        max_substring_bytes,
                        max_substring_bytes,
                        capture_group_id,
                        capture_group_id - 1
                    ).as_str()
                );
            }
        }

        code.push_str("}\n");

        Ok(code)
    }
}
