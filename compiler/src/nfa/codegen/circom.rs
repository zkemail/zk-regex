use std::collections::HashMap;

use crate::nfa::NFAGraph;

impl NFAGraph {
    /// Get all transitions with capture group information
    pub fn get_transitions_with_capture_info(
        &self,
    ) -> Vec<(usize, u8, u8, usize, Option<(usize, bool)>)> {
        let mut transitions = Vec::new();

        // Process each state
        for (state_idx, node) in self.nodes.iter().enumerate() {
            // Group transitions by destination state
            let mut transitions_by_dest: HashMap<usize, Vec<u8>> = HashMap::new();

            // Collect all bytes for each destination
            for (&byte, destinations) in &node.byte_transitions {
                for &dest in destinations {
                    transitions_by_dest.entry(dest).or_default().push(byte);
                }
            }

            // For each destination, find contiguous byte ranges
            for (dest, mut bytes) in transitions_by_dest {
                bytes.sort();

                // Find contiguous ranges
                let mut ranges = Vec::new();
                if !bytes.is_empty() {
                    let mut start = bytes[0];
                    let mut end = bytes[0];

                    for i in 1..bytes.len() {
                        if bytes[i] == end + 1 {
                            // Continue the current range
                            end = bytes[i];
                        } else {
                            // End the current range and start a new one
                            ranges.push((start, end));
                            start = bytes[i];
                            end = bytes[i];
                        }
                    }

                    // Add the last range
                    ranges.push((start, end));
                }

                // Get capture group info for this state
                let capture_info = if !node.capture_groups.is_empty() {
                    // Instead of just using the first capture group, we'll handle all of them
                    // by creating separate transitions for each capture group
                    for (start, end) in ranges.clone() {
                        for &capture_group in &node.capture_groups[1..] {
                            transitions.push((state_idx, start, end, dest, Some(capture_group)));
                        }
                    }
                    // Return the first capture group for the main transition
                    Some(node.capture_groups[0])
                } else {
                    None
                };

                // Add the ranges to the result
                for (start, end) in ranges {
                    transitions.push((state_idx, start, end, dest, capture_info));
                }
            }
        }

        transitions
    }

    /// Generate Circom-compatible transition data
    pub fn generate_circom_data(
        &self,
    ) -> (
        Vec<usize>,
        Vec<usize>,
        Vec<(usize, u8, u8, usize, Option<(usize, bool)>)>,
    ) {
        let start_states = self.start_states.iter().cloned().collect();
        let accept_states = self.accept_states.iter().cloned().collect();
        let transitions = self.get_transitions_with_capture_info();

        (start_states, accept_states, transitions)
    }

    /// Generate Circom code for the NFA
    pub fn generate_circom_code(&self, regex_name: &str, regex_pattern: &str) -> String {
        let (start_states, accept_states, transitions) = self.generate_circom_data();

        // Check if we have any capture groups
        let has_capture_groups = transitions
            .iter()
            .any(|(_, _, _, _, capture_info)| capture_info.is_some());

        let mut code = String::new();

        code.push_str("pragma circom 2.1.5;\n\n");

        code.push_str("include \"circomlib/comparators.circom\";\n");
        code.push_str("include \"circomlib/gates.circom\";\n");
        code.push_str("include \"@zk-email/zk-regex-circom/circuits/regex_helpers.circom\";\n\n");

        code.push_str(format!("// regex: {}\n", regex_pattern).as_str());
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
        code.push_str("        isWithinPathLength[i] <== LessThan(log2Ceil(maxBytes))([i, traversalPathLength]);\n\n");

        code.push_str("        // Check if the traversal is a valid path\n");
        code.push_str("        if (i != maxBytes - 1) {\n");
        code.push_str(
            "            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);\n",
        );
        code.push_str("            isTransitionLinked[i] === isWithinPathLength[i];\n");
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
                            "        // Transition: {} -[{}]-> {} | Capture Group: ({}, {})\n",
                            transition_idx,
                            start,
                            next_state,
                            capture_group_id,
                            capture_group_start
                        )
                        .as_str(),
                    );
                    code.push_str(format!("        isValidTransition[{}][i] <== CheckByteTransitionWithCapture()({}, {}, {}, {}, {}, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);\n", transition_idx, curr_state, next_state, start, capture_group_id, capture_group_start).as_str());
                } else {
                    code.push_str(
                        format!(
                            "        // Transition: {} -[{}-{}]-> {} | Capture Group: ({}, {})\n",
                            transition_idx,
                            start,
                            end,
                            next_state,
                            capture_group_id,
                            capture_group_start
                        )
                        .as_str(),
                    );
                    code.push_str(format!("        isValidTransition[{}][i] <== CheckByteRangeTransitionWithCapture()({}, {}, {}, {}, {}, {}, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);\n", transition_idx, curr_state, next_state, start, end, capture_group_id, capture_group_start).as_str());
                }
            }
        } else {
            for (transition_idx, (curr_state, start, end, next_state, _)) in
                transitions.iter().enumerate()
            {
                if start == end {
                    code.push_str(
                        format!(
                            "        // Transition: {} -[{}]-> {}\n",
                            transition_idx, start, next_state,
                        )
                        .as_str(),
                    );
                    code.push_str(format!("        isValidTransition[{}][i] <== CheckByteTransition()({}, {}, {}, currStates[i], nextStates[i], haystack[i]);\n", transition_idx, curr_state, next_state, start).as_str());
                } else {
                    code.push_str(
                        format!(
                            "        // Transition: {} -[{}-{}]-> {}\n",
                            transition_idx, start, end, next_state,
                        )
                        .as_str(),
                    );
                    code.push_str(format!("        isValidTransition[{}][i] <== CheckByteRangeTransition()({}, {}, {}, {}, currStates[i], nextStates[i], haystack[i]);\n", transition_idx, curr_state, next_state, start, end).as_str());
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
            "        reachedLastTransition[i] <== IsEqual()([i, traversalPathLength]);\n",
        );

        if accept_states.len() > 1 {
            code.push_str("        reachedAcceptState[i] <== MultiOR(numAcceptStates);\n");
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
        code.push_str("    isValidRegex[maxBytes-1] === 1;\n");
        code.push_str("}\n");

        code
    }
}
