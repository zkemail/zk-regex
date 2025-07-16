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

use serde::Serialize;

use crate::ir::NFAGraph;
use crate::passes::{NFAError, NFAResult};

use super::{escape_regex_for_display, generate_circuit_data};

#[derive(Serialize)]
pub struct CircomInputs {
    #[serde(rename = "inHaystack")]
    pub in_haystack: Vec<u8>,
    #[serde(rename = "matchStart")]
    pub match_start: usize,
    #[serde(rename = "matchLength")]
    pub match_length: usize,
    #[serde(rename = "currStates")]
    pub curr_states: Vec<usize>,
    #[serde(rename = "nextStates")]
    pub next_states: Vec<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "captureGroupIds")]
    pub capture_group_ids: Option<Vec<Vec<usize>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "captureGroupStarts")]
    pub capture_group_starts: Option<Vec<Vec<u8>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "captureGroupStartIndices")]
    pub capture_group_start_indices: Option<Vec<usize>>,
}

// From implementation moved to shared.rs

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
    nfa: &NFAGraph,
    regex_name: &str,
    regex_pattern: &str,
    max_substring_bytes: Option<Vec<usize>>,
) -> NFAResult<String> {
    if regex_name.is_empty() {
        return Err(NFAError::InvalidInput("Empty regex name".into()));
    }

    let (start_states, accept_states, transitions) = generate_circuit_data(nfa)?;

    if nfa.num_capture_groups > 0 {
        if let Some(max_bytes) = max_substring_bytes.as_ref() {
            if max_bytes.len() != nfa.num_capture_groups {
                return Err(NFAError::InvalidCapture(format!(
                    "Insufficient max_substring_bytes: need {} but got {}",
                    nfa.num_capture_groups,
                    max_bytes.len()
                )));
            }
            for bytes in max_bytes {
                if *bytes == 0 {
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

    let mut code = String::new();

    code.push_str("pragma circom 2.1.5;\n\n");

    code.push_str("include \"circomlib/circuits/comparators.circom\";\n");
    code.push_str("include \"circomlib/circuits/gates.circom\";\n");
    code.push_str("include \"@zk-email/zk-regex-circom/circuits/regex_helpers.circom\";\n");
    code.push_str("include \"@zk-email/circuits/utils/array.circom\";\n");
    code.push_str("include \"@zk-email/circuits/utils/regex.circom\";\n\n");

    let display_pattern = escape_regex_for_display(regex_pattern);
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
    if nfa.num_capture_groups > 0 {
        for i in 0..nfa.num_capture_groups {
            code.push_str(
                format!("    signal input captureGroup{}Id[maxMatchBytes];\n", i + 1).as_str(),
            );
        }
        for i in 0..nfa.num_capture_groups {
            code.push_str(
                format!(
                    "    signal input captureGroup{}Start[maxMatchBytes];\n",
                    i + 1
                )
                .as_str(),
            );
        }
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
        code.push_str("    isValidStartState <== IsEqual()([startStates[0], currStates[0]]);\n\n");
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
    code.push_str("            isTransitionLinked[i] * isWithinPathLengthMinusOne[i] === isWithinPathLengthMinusOne[i];\n");
    code.push_str("        }\n\n");

    if nfa.num_capture_groups > 0 {
        // Prepare strings for input signal arrays, used in each transition's Circom call
        let input_signal_cg_ids_list_str = (1..=nfa.num_capture_groups)
            .map(|k| format!("captureGroup{}Id[i]", k))
            .collect::<Vec<_>>()
            .join(", ");
        let input_signal_cg_starts_list_str = (1..=nfa.num_capture_groups)
            .map(|k| format!("captureGroup{}Start[i]", k))
            .collect::<Vec<_>>()
            .join(", ");

        for (transition_idx, (curr_state, start, end, next_state, capture_info)) in
            transitions.iter().enumerate()
        {
            // These vectors store the properties of *this specific transition*
            // regarding which capture groups it affects and how.
            let mut transition_prop_cg_ids = vec![0; nfa.num_capture_groups];
            let mut transition_prop_cg_starts = vec![0; nfa.num_capture_groups];

            let capture_details_for_comment = capture_info
                .as_ref()
                .map(|infos| {
                    infos
                        .iter()
                        .map(|(id, is_start_bool)| {
                            if *id > 0 && *id <= nfa.num_capture_groups {
                                transition_prop_cg_ids[*id - 1] = *id;
                                transition_prop_cg_starts[*id - 1] = *is_start_bool as u8;
                            }
                            format!("({}, {})", id, *is_start_bool as u8)
                        })
                        .collect::<Vec<String>>()
                        .join(", ")
                })
                .unwrap_or_else(|| "".to_string());

            let capture_comment_segment = if capture_details_for_comment.is_empty() {
                "Capture Group: []".to_string()
            } else {
                format!("Capture Group:[ {}]", capture_details_for_comment)
            };

            // String representation of this transition's capture group properties
            let transition_prop_cg_ids_str = transition_prop_cg_ids
                .iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(", ");
            let transition_prop_cg_starts_str = transition_prop_cg_starts
                .iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(", ");

            if start == end {
                code.push_str(
                    format!(
                        "        // Transition {}: {} -[{}]-> {} | {}\n",
                        transition_idx, curr_state, start, next_state, capture_comment_segment
                    )
                    .as_str(),
                );
                code.push_str(
                    format!(
                        "        isValidTransition[{}][i] <== CheckByteTransitionWithCapture({})({}, {}, {}, [{}], [{}], currStates[i], nextStates[i], haystack[i], [{}], [{}]);\n",
                        transition_idx,
                        nfa.num_capture_groups,
                        curr_state,
                        next_state,
                        start,
                        transition_prop_cg_ids_str,
                        transition_prop_cg_starts_str,
                        input_signal_cg_ids_list_str, // Array of input signals
                        input_signal_cg_starts_list_str // Array of input signals
                    ).as_str()
                );
            } else {
                code.push_str(
                    format!(
                        "        // Transition {}: {} -[{}-{}]-> {} | {}\n",
                        transition_idx, curr_state, start, end, next_state, capture_comment_segment
                    )
                    .as_str(),
                );
                code.push_str(
                    format!(
                        "        isValidTransition[{}][i] <== CheckByteRangeTransitionWithCapture({})({}, {}, {}, {}, [{}], [{}], currStates[i], nextStates[i], haystack[i], [{}], [{}]);\n",
                        transition_idx,
                        nfa.num_capture_groups,
                        curr_state,
                        next_state,
                        start,
                        end,
                        transition_prop_cg_ids_str,
                        transition_prop_cg_starts_str,
                        input_signal_cg_ids_list_str, // Array of input signals
                        input_signal_cg_starts_list_str // Array of input signals
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

    code.push_str("        // Check if any accept state has been reached at the last transition\n");
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

    if nfa.num_capture_groups > 0 {
        code.push_str(
            format!(
                "    signal input captureGroupStartIndices[{}];\n\n",
                nfa.num_capture_groups
            )
            .as_str(),
        );
        for capture_group_id in 1..=nfa.num_capture_groups {
            let max_substring_bytes =
                if let Some(max_substring_bytes) = max_substring_bytes.as_ref() {
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
                    "    signal output capture{}[{}] <== CaptureSubstring(maxMatchBytes, {}, {})(captureGroupStartIndices[{}], haystack, captureGroup{}Id, captureGroup{}Start);\n",
                    capture_group_id,
                    max_substring_bytes,
                    max_substring_bytes,
                    capture_group_id,
                    capture_group_id - 1,
                    capture_group_id,
                    capture_group_id
                ).as_str()
            );
        }
    }

    code.push_str("}\n");

    Ok(code)
}
