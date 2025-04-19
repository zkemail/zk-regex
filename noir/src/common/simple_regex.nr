use crate::utils::{
   select_subarray,
   sparse_array::SparseArray,
   transitions::check_transition
};

global TRANSITION_TABLE: SparseArray<6, Field> = SparseArray {
    keys: [0x00000000, 0x00016362, 0x00016363, 0x00016364, 0x00046a66, 0x00046a67, 0x00046a69, 0x00ca91cd],
    values: [0x00000000, 0x00000000, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000000],
    maximum: 0x00ca91cd
};


/**
 * Constrains a start state to be valid
 * @dev start states are hardcoded in this function - "(start_state - {state})" for each start
 *      example: `(start_state - 0) * (start_state - 1) * (start_state - 2)` means 0, 1, or 2
 *      are valid first states
 * 
 * @param start_state - The start state of the NFA
 */
fn check_start_state(start_state: Field) {
    let valid_start_state = (start_state - 0) * (start_state - 2) * (start_state - 3);
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
    let accept_state_reached = (next_state - 4);
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
) {
    // regex:"a*b"
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
        check_transition(
            TRANSITION_TABLE,
            haystack[i] as Field,
            current_states[i],
            next_states[i],
            reached_end_state
        );
        reached_end_state = reached_end_state * check_accept_state(
            next_states[i],
            i as Field,
            match_length as Field,
        );
    }
    assert(reached_end_state == 0, "Did not reach a valid end state");
}

