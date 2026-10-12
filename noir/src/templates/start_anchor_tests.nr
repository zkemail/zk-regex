// Regression tests for `^` in `(?:\r\n|^)from:([^\r\n]+)\r\n`.
//
// The anchor used to compile to an unconditional transition, so a prover could point
// `match_start` at a `from:` in the middle of the haystack, e.g. inside `subject:from:x\r\n`.
// A path may now only take the `^` branch from the anchored start state, which requires
// `match_start == 0`.

use super::circuits::from_all_regex::regex_match;

global MAX_HAYSTACK_LEN: u32 = 32;
global MAX_MATCH_LEN: u32 = 16;

// State 19 is the anchored start state of from_all (see `anchored_start_states` in
// templates/graphs/from_all_graph.json); it is the only start state with a transition on `f`.
global PATH_CURRENT: [Field; 8] = [19, 4, 5, 6, 7, 8, 16, 17];
global PATH_NEXT: [Field; 8] = [4, 5, 6, 7, 8, 16, 17, 18];

fn haystack_with(prefix: [u8; 8], header: [u8; 8]) -> [u8; MAX_HAYSTACK_LEN] {
    let mut haystack = [0; MAX_HAYSTACK_LEN];
    for i in 0..8 {
        haystack[i] = prefix[i];
        haystack[i + 8] = header[i];
    }
    haystack
}

fn run(haystack: [u8; MAX_HAYSTACK_LEN], match_start: u32, first_state: Field) {
    let mut current_states = [0; MAX_MATCH_LEN];
    let mut next_states = [0; MAX_MATCH_LEN];
    let mut capture_ids = [0; MAX_MATCH_LEN];
    let mut capture_starts = [0; MAX_MATCH_LEN];
    for i in 0..8 {
        current_states[i] = PATH_CURRENT[i];
        next_states[i] = PATH_NEXT[i];
    }
    current_states[0] = first_state;
    // the single-byte capture of `x`
    capture_ids[5] = 1;
    capture_starts[5] = 1;

    let capture = regex_match::<MAX_HAYSTACK_LEN, MAX_MATCH_LEN>(
        haystack,
        match_start,
        8,
        current_states,
        next_states,
        capture_ids,
        capture_starts,
        [5],
    );
    assert(capture.len() == 1);
    assert(capture.get(0) == "x".as_bytes()[0]);
}

#[test]
fn accepts_first_line_header() {
    // "from:x\r\n" at offset 0
    let header = [102, 114, 111, 109, 58, 120, 13, 10];
    let mut haystack = [0; MAX_HAYSTACK_LEN];
    for i in 0..8 {
        haystack[i] = header[i];
    }
    run(haystack, 0, 19);
}

#[test(should_fail_with = "Start anchor requires match_start == 0")]
fn rejects_anchored_start_mid_haystack() {
    // "subject:from:x\r\n": the only `from:` is at offset 8, after ':' rather than CRLF
    let haystack = haystack_with(
        [115, 117, 98, 106, 101, 99, 116, 58],
        [102, 114, 111, 109, 58, 120, 13, 10],
    );
    run(haystack, 8, 19);
}

#[test(should_fail_with = "Invalid Transition")]
fn rejects_unanchored_start_on_from() {
    // The witness from the report: begin in the unanchored start state 0 and read `f`.
    let haystack = haystack_with(
        [115, 117, 98, 106, 101, 99, 116, 58],
        [102, 114, 111, 109, 58, 120, 13, 10],
    );
    run(haystack, 8, 0);
}
