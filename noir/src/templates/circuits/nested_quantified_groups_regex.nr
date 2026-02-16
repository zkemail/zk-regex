use zkregex::utils::{
   select_subarray,
   sparse_array::SparseArray,
   transitions::check_transition
};

global TRANSITION_TABLE: SparseArray<124, Field> = SparseArray {
    keys: [0x00000000, 0x00026563, 0x00026564, 0x00026565, 0x00026566, 0x00026664, 0x00026665, 0x00026666, 0x00026667, 0x00026765, 0x00026766, 0x00026767, 0x00026768, 0x00026866, 0x00026867, 0x00026868, 0x00026869, 0x00026967, 0x00026968, 0x00026969, 0x0002696a, 0x00026a68, 0x00026a69, 0x00026a6a, 0x00026a6b, 0x00026b69, 0x00026b6a, 0x00026b6b, 0x00026b6c, 0x00026c6a, 0x00026c6b, 0x00026c6c, 0x00026c6d, 0x00026d6b, 0x00026d6c, 0x00026d6d, 0x00026d6e, 0x00026e6c, 0x00026e6d, 0x00026e6e, 0x00026e6f, 0x00026f6d, 0x00026f6e, 0x00026f6f, 0x00026f70, 0x0002706e, 0x0002706f, 0x00027070, 0x00027071, 0x0002716f, 0x00027170, 0x00027171, 0x00027172, 0x00027270, 0x00027271, 0x00027272, 0x00027273, 0x00027371, 0x00027372, 0x00027373, 0x00027374, 0x00027472, 0x00027473, 0x00027474, 0x00027475, 0x00027573, 0x00027574, 0x00027575, 0x00027576, 0x00027674, 0x00027675, 0x00027676, 0x00027677, 0x00027775, 0x00027776, 0x00027777, 0x00027778, 0x00027876, 0x00027877, 0x00027878, 0x00027879, 0x00027977, 0x00027978, 0x00027979, 0x0002797a, 0x00027a78, 0x00027a79, 0x00027a7a, 0x00027a7b, 0x00027b79, 0x00027b7a, 0x00027b7b, 0x00027b7c, 0x00027c7a, 0x00027c7b, 0x00027c7c, 0x00027c7d, 0x00027d7b, 0x00027d7c, 0x00027d7d, 0x00027d7e, 0x00027e7c, 0x00027e7d, 0x00027e7e, 0x00027e7f, 0x00033635, 0x00033636, 0x00033736, 0x00033737, 0x00033837, 0x00033838, 0x00033938, 0x00033939, 0x00033a39, 0x00033a3a, 0x00033b3a, 0x00033b3b, 0x00033c3b, 0x00033c3c, 0x00033d3c, 0x00033d3d, 0x00033e3d, 0x00033e3e, 0x00033f3e, 0x00033f3f, 0x00ca91cd],
    values: [0x00000000, 0x00000000, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000000],
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
    let valid_start_state = (start_state - 0) * (start_state - 1);
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
    let accept_state_reached = (next_state - 3);
    let accept_state_reached_bool = (accept_state_reached == 0) as Field;

    // check if the haystack index is the asserted match length
    // should equal 1 since haystack_index should be 1 less than asserted_match)length
    let asserted_path_traversed = (asserted_match_length - haystack_index == 1) as Field;

    (1 - (accept_state_reached_bool * asserted_path_traversed))
}

/**
 * NestedQuantifiedGroupsRegex matching function
 * Regex: (?:[a-z]+[0-9]+)+
 * @param in_haystack - The input haystack to search from
 * @param match_start - The start index in the haystack for the subarray to match from
 * @param match_length - The length of the subarray to extract from haystack
 * @param current_states - The current states of the NFA at each index in the match subarray
 * @param next_states - The next states of the NFA at each index in the match subarray
 */
pub fn regex_match<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(
    in_haystack: [u8; MAX_HAYSTACK_LEN],
    match_start: u32,
    match_length: u32,
    current_states: [Field; MAX_MATCH_LEN],
    next_states: [Field; MAX_MATCH_LEN],
) {
    // resize haystack 
    let haystack: [u8; MAX_MATCH_LEN] = select_subarray::<MAX_HAYSTACK_LEN, MAX_MATCH_LEN>(in_haystack, match_start, match_length);

    check_start_state(current_states[0]);
    for i in 0..MAX_MATCH_LEN-1 {
        // match length - 1 since current states should be 1 less than next states
        let in_range = (i < match_length - 1) as Field;
        let matching_states = current_states[i + 1] - next_states[i];
        assert(in_range * matching_states == 0, "Invalid Transition Input");
    }
    let mut reached_end_state = 1;
    for i in 0..MAX_MATCH_LEN {
        check_transition(
            TRANSITION_TABLE,
            haystack[i] as Field,
            current_states[i],
            next_states[i],
            reached_end_state
        );
        reached_end_state = reached_end_state * check_accept_state(next_states[i], i as Field, match_length as Field);
    }
    assert(reached_end_state == 0, "Did not reach a valid end state");

}

