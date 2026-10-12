//! Intermediate NFA representation during compilation
//!
//! This module contains the intermediate representation used during the compilation
//! pipeline. The intermediate NFA may contain epsilon transitions and other constructs
//! that need to be processed before generating the final circuit-ready representation.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

use super::nfa::{NFAGraph, NFANode};
use crate::passes::{NFAError, NFAResult};

/// Intermediate NFA node that may contain epsilon transitions
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct IntermediateNFANode {
    /// Unique identifier for this state
    pub state_id: usize,

    /// Byte-consuming transitions: byte -> set of target states
    pub byte_transitions: BTreeMap<u8, BTreeSet<usize>>,

    /// Epsilon (non-consuming) transitions to other states
    pub epsilon_transitions: BTreeSet<usize>,

    /// Epsilon transitions guarded by a start anchor (`^` or `\A`). They only hold at haystack
    /// offset 0, so epsilon elimination follows them only from the start of a match.
    #[serde(default)]
    pub start_anchor_transitions: BTreeSet<usize>,

    /// Capture group information: target_state -> capture_events
    pub capture_groups: BTreeMap<usize, BTreeSet<(usize, bool)>>,
}

/// Intermediate NFA representation used during compilation
///
/// This representation may contain epsilon transitions and other intermediate
/// constructs that need to be processed before circuit generation.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct IntermediateNFA {
    /// The original regex pattern
    pub regex: String,

    /// All states in the intermediate NFA
    pub nodes: Vec<IntermediateNFANode>,

    /// Set of start state indices
    pub start_states: BTreeSet<usize>,

    /// Start states that are only valid when the match begins at haystack offset 0.
    /// Always a subset of `start_states`.
    #[serde(default)]
    pub anchored_start_states: BTreeSet<usize>,

    /// Set of accept state indices
    pub accept_states: BTreeSet<usize>,

    /// Number of capture groups in the regex
    pub num_capture_groups: usize,
}

impl IntermediateNFA {
    /// Create a new empty intermediate NFA
    pub fn new(regex: String) -> Self {
        Self {
            regex,
            nodes: Vec::new(),
            start_states: BTreeSet::new(),
            anchored_start_states: BTreeSet::new(),
            accept_states: BTreeSet::new(),
            num_capture_groups: 0,
        }
    }

    /// Validate the structural integrity of the intermediate NFA
    pub fn validate(&self) -> NFAResult<()> {
        if self.nodes.is_empty() {
            return Err(NFAError::EmptyAutomaton(
                "No states in intermediate NFA".into(),
            ));
        }

        if self.start_states.is_empty() {
            return Err(NFAError::Verification("No start states defined".into()));
        }

        // Validate state IDs are sequential and match indices
        for (idx, node) in self.nodes.iter().enumerate() {
            if node.state_id != idx {
                return Err(NFAError::InvalidStateId(format!(
                    "State ID {} doesn't match index {} in intermediate NFA",
                    node.state_id, idx
                )));
            }
        }

        // Validate transition targets are within bounds
        for (state_idx, node) in self.nodes.iter().enumerate() {
            // Check byte transitions
            for destinations in node.byte_transitions.values() {
                for &dest in destinations {
                    if dest >= self.nodes.len() {
                        return Err(NFAError::InvalidTransition(format!(
                            "Byte transition from state {state_idx} to invalid state {dest}"
                        )));
                    }
                }
            }

            // Check epsilon transitions
            for &dest in node
                .epsilon_transitions
                .iter()
                .chain(&node.start_anchor_transitions)
            {
                if dest >= self.nodes.len() {
                    return Err(NFAError::InvalidTransition(format!(
                        "Epsilon transition from state {state_idx} to invalid state {dest}"
                    )));
                }
            }
        }

        Ok(())
    }

    /// Convert the intermediate NFA to a final circuit-ready NFA
    ///
    /// This process eliminates epsilon transitions and creates a clean
    /// final representation suitable for circuit generation.
    pub fn finalize(self) -> NFAResult<NFAGraph> {
        // Create a mutable copy for epsilon elimination
        let mut intermediate = self;

        // Remove epsilon transitions using the existing algorithm
        intermediate.remove_epsilon_transitions()?;

        // Convert to final representation (no epsilon transitions)
        let final_nodes: Vec<NFANode> = intermediate
            .nodes
            .into_iter()
            .map(|intermediate_node| NFANode {
                state_id: intermediate_node.state_id,
                byte_transitions: intermediate_node.byte_transitions,
                capture_groups: intermediate_node.capture_groups,
            })
            .collect();

        let final_nfa = NFAGraph {
            regex: intermediate.regex,
            nodes: final_nodes,
            start_states: intermediate.start_states,
            anchored_start_states: intermediate.anchored_start_states,
            accept_states: intermediate.accept_states,
            num_capture_groups: intermediate.num_capture_groups,
        };

        // Final validation
        final_nfa.verify()?;

        Ok(final_nfa)
    }
}

// Implement epsilon transition removal for intermediate NFA
impl IntermediateNFA {
    /// Remove epsilon transitions while preserving language semantics
    fn remove_epsilon_transitions(&mut self) -> NFAResult<()> {
        // Compute epsilon closures for all states. These closures never cross a start anchor:
        // a `^` reached after consuming a byte sits at haystack offset >= 1 and can never hold.
        let closures = self.compute_epsilon_closures()?;

        let mut new_transitions = Vec::with_capacity(self.nodes.len());
        let mut new_captures = Vec::with_capacity(self.nodes.len());
        let mut new_start_states = BTreeSet::new();
        let mut new_accept_states = BTreeSet::new();

        // Process epsilon closures and create new transitions
        for (state, closure) in closures.iter().enumerate() {
            // Mark state as accepting if any state in closure is accepting
            if closure.is_accept {
                new_accept_states.insert(state);
            }

            let (transitions, captures) = self.closure_byte_transitions(closure, &closures);
            new_transitions.push(transitions);
            new_captures.push(captures);
        }

        // Handle start states carefully to preserve capture semantics
        let original_starts: BTreeSet<usize> = self.start_states.iter().copied().collect();

        for &orig_start in &original_starts {
            new_start_states.insert(orig_start);

            // Check if start state's closure has start captures on any epsilon path
            let has_start_captures = closures
                .get(orig_start)
                .map(|closure| {
                    closure
                        .per_state_captures
                        .values()
                        .any(|captures| captures.iter().any(|(_, is_start)| *is_start))
                })
                .unwrap_or(false);

            // Only add alternative start states if no start captures would be bypassed
            if !has_start_captures {
                if let Some(closure) = closures.get(orig_start) {
                    for &r_state in &closure.states {
                        if r_state != orig_start
                            && !self.nodes[r_state].byte_transitions.is_empty()
                        {
                            new_start_states.insert(r_state);
                        }
                    }
                }
            }
        }

        // A path that begins at the start of the haystack may also cross start anchors. Give each
        // start state whose closure reaches one an anchored twin: a fresh state with the
        // transitions of the closure that does cross them. Nothing transitions into the twin, so
        // it can only be the first state of a path, and the backends only accept it when the
        // match begins at haystack offset 0.
        let mut new_anchored_start_states = BTreeSet::new();
        for &orig_start in &original_starts {
            let anchored_closure = self.compute_closure(orig_start, true)?;
            if anchored_closure.states == closures[orig_start].states {
                continue;
            }

            let twin = self.nodes.len() + new_anchored_start_states.len();
            let (transitions, captures) =
                self.closure_byte_transitions(&anchored_closure, &closures);
            new_transitions.push(transitions);
            new_captures.push(captures);
            if anchored_closure.is_accept {
                new_accept_states.insert(twin);
            }
            new_start_states.insert(twin);
            new_anchored_start_states.insert(twin);
        }
        for twin in self.nodes.len()..self.nodes.len() + new_anchored_start_states.len() {
            self.nodes.push(IntermediateNFANode {
                state_id: twin,
                ..Default::default()
            });
        }

        // Apply the changes
        self.start_states = new_start_states;
        self.anchored_start_states = new_anchored_start_states;
        self.accept_states = new_accept_states;

        for (state, (transitions, captures)) in new_transitions
            .into_iter()
            .zip(new_captures.into_iter())
            .enumerate()
        {
            self.nodes[state].byte_transitions = transitions;
            self.nodes[state].capture_groups = captures;
            // Remove all epsilon transitions
            self.nodes[state].epsilon_transitions.clear();
            self.nodes[state].start_anchor_transitions.clear();
        }

        // Clean up unreachable states
        self.remove_unreachable_states();

        Ok(())
    }

    /// Collect the byte transitions (and their capture events) available from an epsilon
    /// closure, bypassing the epsilon transitions that lead to them.
    fn closure_byte_transitions(
        &self,
        closure: &EpsilonClosure,
        closures: &[EpsilonClosure],
    ) -> (
        BTreeMap<u8, BTreeSet<usize>>,
        BTreeMap<usize, BTreeSet<(usize, bool)>>,
    ) {
        let mut new_transitions: BTreeMap<u8, BTreeSet<usize>> = BTreeMap::new();
        let mut new_captures: BTreeMap<usize, BTreeSet<(usize, bool)>> = BTreeMap::new();

        // For each state reachable via epsilon that has byte transitions
        for &r_state in &closure.states {
            // Create direct byte transitions bypassing epsilon transitions
            for (&byte, targets) in &self.nodes[r_state].byte_transitions {
                for &actual_target in targets {
                    new_transitions
                        .entry(byte)
                        .or_default()
                        .insert(actual_target);

                    // Merge capture group information
                    let captures_for_transition = new_captures.entry(actual_target).or_default();

                    // Add start captures from epsilon path before byte transition
                    // CRITICAL FIX: Only add captures from the specific epsilon path to r_state
                    if let Some(path_captures) = closure.per_state_captures.get(&r_state) {
                        for &(group_id, is_start) in path_captures {
                            if is_start {
                                captures_for_transition.insert((group_id, true));
                            }
                        }
                    }

                    // Add end captures from epsilon path after byte transition
                    // For end markers, we need ALL end captures reachable from actual_target
                    let target_closure = &closures[actual_target];
                    for path_captures in target_closure.per_state_captures.values() {
                        for &(group_id, is_start) in path_captures {
                            if !is_start {
                                captures_for_transition.insert((group_id, false));
                            }
                        }
                    }
                }
            }
        }

        (new_transitions, new_captures)
    }

    /// Compute epsilon closures using the existing algorithm
    fn compute_epsilon_closures(&self) -> NFAResult<Vec<EpsilonClosure>> {
        let mut closures = Vec::new();
        for state in 0..self.nodes.len() {
            closures.push(self.compute_closure(state, false)?);
        }
        Ok(closures)
    }

    /// Compute the epsilon closure of `start`. Start-anchor edges are only followed when
    /// `cross_start_anchors` is set, i.e. when `start` is known to sit at haystack offset 0.
    fn compute_closure(
        &self,
        start: usize,
        cross_start_anchors: bool,
    ) -> NFAResult<EpsilonClosure> {
        let mut closure = EpsilonClosure {
            states: BTreeSet::new(),
            per_state_captures: BTreeMap::new(),
            is_accept: false,
        };

        fn dfs(
            nfa: &IntermediateNFA,
            state: usize,
            cross_start_anchors: bool,
            closure: &mut EpsilonClosure,
            visited: &mut BTreeSet<usize>,
            current_path_captures: &BTreeSet<(usize, bool)>,
        ) -> NFAResult<()> {
            if !visited.insert(state) {
                return Ok(());
            }

            closure.states.insert(state);

            // Build up captures for the current path
            let mut path_captures = current_path_captures.clone();

            // Add captures from this state's epsilon transitions
            for (&capture_state, captures) in &nfa.nodes[state].capture_groups {
                for capture in captures {
                    path_captures.insert(*capture);
                }
            }

            // Store the captures for this specific path to this state
            closure
                .per_state_captures
                .entry(state)
                .or_insert_with(BTreeSet::new)
                .extend(path_captures.iter().cloned());

            // Check if this state is accepting
            if nfa.accept_states.contains(&state) {
                closure.is_accept = true;
            }

            // Follow epsilon transitions, passing accumulated captures
            let node = &nfa.nodes[state];
            let anchors = cross_start_anchors
                .then_some(&node.start_anchor_transitions)
                .into_iter()
                .flatten();
            for &next in node.epsilon_transitions.iter().chain(anchors) {
                dfs(nfa, next, cross_start_anchors, closure, visited, &path_captures)?;
            }

            Ok(())
        }

        let mut visited = BTreeSet::new();
        let initial_captures = BTreeSet::new();
        dfs(
            self,
            start,
            cross_start_anchors,
            &mut closure,
            &mut visited,
            &initial_captures,
        )?;

        Ok(closure)
    }

    fn remove_unreachable_states(&mut self) {
        // Find reachable states via BFS
        let mut reachable = BTreeSet::new();
        let mut queue = Vec::new();

        // Start from all start states
        for &start in &self.start_states {
            if reachable.insert(start) {
                queue.push(start);
            }
        }

        // BFS to find all reachable states
        while let Some(state) = queue.pop() {
            if state < self.nodes.len() {
                for targets in self.nodes[state].byte_transitions.values() {
                    for &target in targets {
                        if reachable.insert(target) {
                            queue.push(target);
                        }
                    }
                }
            }
        }

        // Remove unreachable states if any exist
        if reachable.len() < self.nodes.len() {
            self.compact_states(reachable);
        }
    }

    fn compact_states(&mut self, reachable: BTreeSet<usize>) {
        // Create mapping from old to new indices
        let mut old_to_new = BTreeMap::new();
        let mut new_nodes = Vec::with_capacity(reachable.len());

        let mut new_idx = 0;
        for &old_idx in &reachable {
            old_to_new.insert(old_idx, new_idx);
            new_idx += 1;
        }

        // Create compacted nodes with updated indices
        for &old_idx in &reachable {
            let mut node = self.nodes[old_idx].clone();
            node.state_id = old_to_new[&old_idx];

            // Update byte transition targets
            let mut new_byte_transitions = BTreeMap::new();
            for (byte, targets) in node.byte_transitions {
                let new_targets: BTreeSet<usize> = targets
                    .into_iter()
                    .filter_map(|target| old_to_new.get(&target).copied())
                    .collect();

                if !new_targets.is_empty() {
                    new_byte_transitions.insert(byte, new_targets);
                }
            }
            node.byte_transitions = new_byte_transitions;

            // Update capture group targets
            let mut new_captures = BTreeMap::new();
            for (target, captures) in node.capture_groups {
                if let Some(&new_target) = old_to_new.get(&target) {
                    new_captures.insert(new_target, captures);
                }
            }
            node.capture_groups = new_captures;

            new_nodes.push(node);
        }

        // Update start and accept states
        self.start_states = self
            .start_states
            .iter()
            .filter_map(|&state| old_to_new.get(&state).copied())
            .collect();

        self.anchored_start_states = self
            .anchored_start_states
            .iter()
            .filter_map(|&state| old_to_new.get(&state).copied())
            .collect();

        self.accept_states = self
            .accept_states
            .iter()
            .filter_map(|&state| old_to_new.get(&state).copied())
            .collect();

        self.nodes = new_nodes;
    }
}

/// Epsilon closure computation helper
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct EpsilonClosure {
    states: BTreeSet<usize>,
    /// Map from reachable state to the captures encountered on epsilon path to that state
    per_state_captures: BTreeMap<usize, BTreeSet<(usize, bool)>>,
    is_accept: bool,
}

/// Information about captures encountered on a specific epsilon path
#[derive(Debug, Clone)]
struct PathInfo {
    /// The destination state of this path
    target_state: usize,
    /// Captures encountered on epsilon transitions along this path
    captures: BTreeSet<(usize, bool)>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_epsilon_elimination_optional_pattern_before_capture() {
        // Test pattern similar to email_addr: optional(?:...)? followed by capture group (...)
        // This is a regression test for the epsilon elimination bug where optional patterns
        // before capture groups caused duplicate capture markers.
        let pattern = r"(?:a)?([bc])";

        // Use the public API through compile function
        let nfa = crate::compile(pattern).expect("Failed to compile pattern");

        // Test that both paths work correctly
        let test_cases = vec![
            ("ab", true),  // Takes optional path
            ("ac", true),  // Takes optional path
            ("b", true),   // Skips optional path
            ("c", true),   // Skips optional path
            ("d", false),  // Should not match
        ];

        for (input, should_match) in test_cases {
            let result = nfa.get_path_to_accept(input.as_bytes());
            assert_eq!(
                result.is_ok(),
                should_match,
                "Pattern {:?} with input {:?}: expected match={}",
                pattern,
                input,
                should_match
            );

            if should_match {
                let path = result.unwrap();
                // Verify exactly ONE capture start event in the path
                let capture_start_count = path
                    .path
                    .iter()
                    .filter(|(_, _, _, captures)| {
                        captures
                            .as_ref()
                            .map(|c| c.iter().any(|&(id, is_start)| id == 1 && is_start))
                            .unwrap_or(false)
                    })
                    .count();

                assert_eq!(
                    capture_start_count, 1,
                    "Expected exactly 1 capture start event for input {:?}, got {}. This test verifies the epsilon elimination fix.",
                    input, capture_start_count
                );
            }
        }
    }

    /// The constraints the generated circuits put on a path, without the capture-group ones: the
    /// first state is a start state (an anchored one only when `match_start == 0`), every step
    /// takes a byte transition on the next haystack byte, consecutive steps link, and the last
    /// step lands in an accept state.
    fn circuit_accepts(nfa: &NFAGraph, haystack: &[u8], match_start: usize, len: usize) -> bool {
        let mut states: BTreeSet<usize> = nfa
            .start_states
            .iter()
            .copied()
            .filter(|s| match_start == 0 || !nfa.anchored_start_states.contains(s))
            .collect();
        for &byte in &haystack[match_start..match_start + len] {
            states = states
                .iter()
                .filter_map(|&s| nfa.nodes[s].byte_transitions.get(&byte))
                .flatten()
                .copied()
                .collect();
        }
        len > 0 && states.iter().any(|s| nfa.accept_states.contains(s))
    }

    /// Whether `re` (built by `window_regex`) matches exactly
    /// `haystack[match_start..match_start + len]`, with look-around assertions evaluated against
    /// the whole haystack. Truncating the haystack at the end of the window makes `$` mean "the
    /// window ends here" while `^` still means "offset 0 of the real haystack".
    fn regex_accepts(
        re: &regex_automata::meta::Regex,
        haystack: &[u8],
        match_start: usize,
        len: usize,
    ) -> bool {
        use regex_automata::{Anchored, Input};

        let end = match_start + len;
        let input = Input::new(&haystack[..end])
            .range(match_start..end)
            .anchored(Anchored::Yes);
        len > 0 && re.is_match(input)
    }

    fn window_regex(pattern: &str) -> regex_automata::meta::Regex {
        regex_automata::meta::Regex::new(&format!("(?:{pattern})$")).unwrap()
    }

    /// Every haystack over `alphabet` up to `max_len` bytes, plus `extra`.
    fn haystacks(alphabet: &[&[u8]], max_len: usize, extra: &[&[u8]]) -> Vec<Vec<u8>> {
        let mut all: Vec<Vec<u8>> = vec![Vec::new()];
        let mut frontier = all.clone();
        for _ in 0..max_len {
            frontier = frontier
                .iter()
                .flat_map(|h| {
                    alphabet.iter().map(move |token| [h.as_slice(), token].concat())
                })
                .filter(|h| h.len() <= max_len)
                .collect();
            all.extend(frontier.iter().cloned());
        }
        all.extend(extra.iter().map(|h| h.to_vec()));
        all
    }

    fn assert_circuit_matches_regex(pattern: &str, haystacks: &[Vec<u8>]) {
        let nfa = crate::compile(pattern).expect("pattern should compile");
        let re = window_regex(pattern);
        for haystack in haystacks {
            for match_start in 0..haystack.len() {
                for len in 1..=haystack.len() - match_start {
                    assert_eq!(
                        circuit_accepts(&nfa, haystack, match_start, len),
                        regex_accepts(&re, haystack, match_start, len),
                        "pattern {pattern:?}, haystack {:?}, matchStart {match_start}, matchLength {len}",
                        String::from_utf8_lossy(haystack),
                    );
                }
            }
        }
    }

    #[test]
    fn start_anchor_is_not_satisfied_mid_haystack() {
        // Regression test: `^` used to compile to a plain epsilon transition, so a prover could
        // point matchStart at a `from:` that is neither at offset 0 nor after CRLF.
        let pattern = "(?:\r\n|^)from:([^\r\n]+)\r\n";
        let nfa = crate::compile(pattern).expect("pattern should compile");
        let haystack = b"subject:from:x\r\n";

        assert!(!circuit_accepts(&nfa, haystack, 8, 8));
        assert!(!regex_accepts(&window_regex(pattern), haystack, 8, 8));

        // Controls: a first-line header and a header after CRLF are still accepted.
        assert!(circuit_accepts(&nfa, b"from:x\r\n", 0, 8));
        assert!(circuit_accepts(&nfa, b"subject:a\r\nfrom:x\r\n", 9, 10));
        assert!(!circuit_accepts(&nfa, haystack, 7, 9));
    }

    #[test]
    fn start_anchor_gets_an_anchored_start_state() {
        let nfa = crate::compile("(?:\r\n|^)from:").expect("pattern should compile");
        assert_eq!(nfa.anchored_start_states.len(), 1);
        assert!(nfa.anchored_start_states.is_subset(&nfa.start_states));

        // Only the anchored start state may take `f` as the first byte.
        for &start in &nfa.start_states {
            let takes_f = nfa.nodes[start].byte_transitions.contains_key(&b'f');
            assert_eq!(takes_f, nfa.anchored_start_states.contains(&start), "state {start}");
        }

        // Nothing transitions into an anchored start state, so it can only begin a path.
        for node in &nfa.nodes {
            for targets in node.byte_transitions.values() {
                assert!(targets.is_disjoint(&nfa.anchored_start_states));
            }
        }

        // Patterns without `^` are unchanged.
        let nfa = crate::compile("(?:\r\n|x)from:").expect("pattern should compile");
        assert!(nfa.anchored_start_states.is_empty());
    }

    #[test]
    fn circuit_paths_agree_with_regex_semantics() {
        let header_haystacks = haystacks(
            &[b"\r\n", b"from:", b"x", b":"],
            10,
            &[b"subject:from:x\r\n", b"from:x\r\nfrom:y\r\n", b"x\r\nfrom:\r\n"],
        );
        for pattern in [
            "(?:\r\n|^)from:([^\r\n]+)\r\n",
            "(?:\r\n|^)from:",
            "\\Afrom:x",
            "^(?:from:|x)+",
        ] {
            assert_circuit_matches_regex(pattern, &header_haystacks);
        }

        let small_haystacks = haystacks(&[b"a", b"b", b"x"], 6, &[]);
        for pattern in [
            "^ab",
            "(^a)b",
            "a|^b",
            "(?:^|x)ab",
            "(?:^|x)(a+)b",
            "x^a",
            "(?:a|^)*b",
            "(?:^a|b)+",
            "a*b",
            "^",
        ] {
            assert_circuit_matches_regex(pattern, &small_haystacks);
        }
    }

    #[test]
    fn anchored_witnesses_only_start_at_offset_zero() {
        let nfa = crate::compile("(?:\r\n|^)from:([^\r\n]+)\r\n").expect("pattern should compile");

        let first_line = nfa.get_path_to_accept(b"from:x\r\n").expect("should match");
        assert_eq!(first_line.span, (0, 8));
        assert!(nfa.anchored_start_states.contains(&first_line.path[0].0));

        let later_line = nfa
            .get_path_to_accept(b"subject:a\r\nfrom:x\r\n")
            .expect("should match");
        assert_eq!(later_line.span, (9, 10));
        assert!(!nfa.anchored_start_states.contains(&later_line.path[0].0));

        assert!(nfa.get_path_to_accept(b"subject:from:x\r\n").is_err());
    }

    #[test]
    fn start_anchor_keeps_captures_before_it() {
        // The capture opens before the `^`, so the anchored start state must carry it.
        let nfa = crate::compile("(^a)b").expect("pattern should compile");
        let path = nfa.get_path_to_accept(b"ab").expect("should match").path;
        let first_captures = path[0].3.clone().unwrap_or_default();
        assert!(first_captures.contains(&(1, true)), "{path:?}");
        assert!(first_captures.contains(&(1, false)), "{path:?}");
    }

    #[test]
    fn rejects_look_arounds_the_circuit_cannot_check() {
        for pattern in ["a$", "a\\z", "(?m)^a", "(?m)a$", "(?Rm)^a", "\\bfoo", "a\\B"] {
            let err = crate::compile(pattern).expect_err(pattern);
            assert!(
                err.to_string().contains("Unsupported regex feature"),
                "{pattern}: {err}"
            );
        }
        for pattern in ["^a", "\\Aa", "(?:\r\n|^)a"] {
            crate::compile(pattern).expect(pattern);
        }
    }
}
