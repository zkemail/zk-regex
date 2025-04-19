use crate::utils::{
   select_subarray,
   captures::capture_substring,
   sparse_array::SparseArray,
   transitions::check_transition_with_captures
};

global TRANSITION_TABLE: SparseArray<66, Field> = SparseArray {
    keys: [0x00000000, 0x0002110f, 0x00021110, 0x0003100f, 0x00047b77, 0x00047b7a, 0x00057f7e, 0x00066e6d, 0x00077877, 0x00087574, 0x00097574, 0x000a8887, 0x000b504f, 0x000c7978, 0x000c7979, 0x000c7a79, 0x000c7a7a, 0x000c7b7a, 0x000c7b7b, 0x000c7c7b, 0x000c7c7c, 0x000c7d7c, 0x000c7d7d, 0x000c7e7d, 0x000c7e7e, 0x000c7f7e, 0x000c7f7f, 0x000c807f, 0x000c8080, 0x000c8180, 0x000c8181, 0x000c8281, 0x000c8282, 0x000c8382, 0x000c8383, 0x000c8483, 0x000c8484, 0x000c8584, 0x000c8585, 0x000c8685, 0x000c8686, 0x000c8786, 0x000c8787, 0x000c8887, 0x000c8888, 0x000c8988, 0x000c8989, 0x000c8a89, 0x000c8a8a, 0x000c8b8a, 0x000c8b8b, 0x000c8c8b, 0x000c8c8c, 0x000c8d8c, 0x000c8d8d, 0x000c8e8d, 0x000c8e8e, 0x000c8f8e, 0x000c8f8f, 0x000c908f, 0x000c9090, 0x000c9190, 0x000c9191, 0x000c9291, 0x000c9292, 0x000d2726, 0x000e2625, 0x00ca91d7],
    values: [0x00000000, 0x00000000, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000007, 0x00000001, 0x00000005, 0x00000001, 0x00000000],
    maximum: 0x00ca91d7
};

pub global CAPTURE_1_MAX_LENGTH: u32 = 64;
pub global NUM_CAPTURE_GROUPS: u32 = 1;

/**
 * Constrains a start state to be valid
 * @dev start states are hardcoded in this function - "(start_state - {state})" for each start
 *      example: `(start_state - 0) * (start_state - 1) * (start_state - 2)` means 0, 1, or 2
 *      are valid first states
 * 
 * @param start_state - The start state of the NFA
 */
fn check_start_state(start_state: Field) {
    let valid_start_state = (start_state - 0) * (start_state - 1) * (start_state - 3);
    assert(valid_start_state == 0, "Invalid start state");
}
    
/**
 * Constrains the recognition of accept_state being reached. If an aceppt state is reached,
 *      ensures asserted traversal path is valid
 * @dev accept states are hardcoded in this function - "(next_state - {state})" for each accept
 *      example: `(next_state - 19) * (next_state - 20) * (next_state - 21)` means 19, 20, or 21
 *      are valid accept states
 * 
 * @param next_state - The asserted next state of the NFA
 * @param haystack_index - The index being operated on in the haystack
 * @param asserted_match_length - The asserted traversal path length
 * @return - 0 if accept_state is reached, nonzero otherwise
 */
fn check_accept_state(
    next_state: Field,
    haystack_index: Field, 
    asserted_match_length: Field
) -> Field {
    // check if the next state is an accept state
    let accept_state_reached = (next_state - 14);
    let accept_state_reached_bool = (accept_state_reached == 0) as Field;

    // check if the haystack index is the asserted match length
    // should equal 1 since haystack_index should be 1 less than asserted_match)length
    let asserted_path_traversed = (asserted_match_length - haystack_index == 1) as Field;

    // if accept state reached, check asserted path traversed. Else return 1
    let valid_condition =
        (1 - accept_state_reached_bool) + (accept_state_reached_bool * asserted_path_traversed);
    assert(valid_condition == 1, "Accept state reached but not at asserted path end");

    // return accept_state reached value
    accept_state_reached
}

pub fn regex_match<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(
    in_haystack: [u8; MAX_HAYSTACK_LEN],
    match_start: u32,
    match_length: u32,
    current_states: [Field; MAX_MATCH_LEN],
    next_states: [Field; MAX_MATCH_LEN],
    capture_group_ids: [Field; MAX_MATCH_LEN],
    capture_group_starts: [Field; MAX_MATCH_LEN],
    capture_group_start_indices: [Field; NUM_CAPTURE_GROUPS],
) -> (BoundedVec<u8, CAPTURE_1_MAX_LENGTH>) {
    // regex:"(?:\r\n|^)subject:([a-z]+)\r\n"
    // resize haystack 
    let haystack: [u8; MAX_MATCH_LEN] = select_subarray(in_haystack, match_start, match_length);

    let mut reached_end_state = 1;
    check_start_state(current_states[0]);
    for i in 0..MAX_MATCH_LEN-1 {
        // match length - 1 since current states should be 1 less than next states
        let in_range = (i < match_length - 1) as Field;
        let matching_states = current_states[i + 1] - next_states[i];
        assert(in_range * matching_states == 0, "Invalid Transition Input");
    }
    for i in 0..MAX_MATCH_LEN {
        check_transition_with_captures(
            TRANSITION_TABLE,
            haystack[i] as Field,
            current_states[i],
            next_states[i],
            capture_group_ids[i],
            capture_group_starts[i],
            reached_end_state
        );
        reached_end_state = reached_end_state * check_accept_state(
            next_states[i],
            i as Field,
            match_length as Field,
        );
    }
    assert(reached_end_state == 0, "Did not reach a valid end state");
     // Capture Group 1
     let capture_1 = capture_substring::<MAX_MATCH_LEN, CAPTURE_1_MAX_LENGTH, 1>(
        haystack,
        capture_group_ids,
        capture_group_starts,
        capture_group_start_indices[0],
     );
    (capture_1)
}

