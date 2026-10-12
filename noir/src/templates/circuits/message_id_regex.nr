use crate::utils::{
   select_subarray,
   captures::capture_substring,
   sparse_array::SparseArray,
   transitions::check_transition_with_captures
};

global TRANSITION_TABLE: SparseArray<156, Field> = SparseArray {
    keys: [0x00000000, 0x020d0000, 0x020d0001, 0x020d0014, 0x030a0002, 0x046d0003, 0x046d0014, 0x05650004, 0x06730005, 0x07730006, 0x08610007, 0x09670008, 0x0a650009, 0x0b2d000a, 0x0c69000b, 0x0d64000c, 0x0e3a000d, 0x0f3c000e, 0x102b000f, 0x102b0010, 0x102d000f, 0x102d0010, 0x102e000f, 0x102e0010, 0x1030000f, 0x10300010, 0x1031000f, 0x10310010, 0x1032000f, 0x10320010, 0x1033000f, 0x10330010, 0x1034000f, 0x10340010, 0x1035000f, 0x10350010, 0x1036000f, 0x10360010, 0x1037000f, 0x10370010, 0x1038000f, 0x10380010, 0x1039000f, 0x10390010, 0x103d000f, 0x103d0010, 0x1040000f, 0x10400010, 0x1041000f, 0x10410010, 0x1042000f, 0x10420010, 0x1043000f, 0x10430010, 0x1044000f, 0x10440010, 0x1045000f, 0x10450010, 0x1046000f, 0x10460010, 0x1047000f, 0x10470010, 0x1048000f, 0x10480010, 0x1049000f, 0x10490010, 0x104a000f, 0x104a0010, 0x104b000f, 0x104b0010, 0x104c000f, 0x104c0010, 0x104d000f, 0x104d0010, 0x104e000f, 0x104e0010, 0x104f000f, 0x104f0010, 0x1050000f, 0x10500010, 0x1051000f, 0x10510010, 0x1052000f, 0x10520010, 0x1053000f, 0x10530010, 0x1054000f, 0x10540010, 0x1055000f, 0x10550010, 0x1056000f, 0x10560010, 0x1057000f, 0x10570010, 0x1058000f, 0x10580010, 0x1059000f, 0x10590010, 0x105a000f, 0x105a0010, 0x105f000f, 0x105f0010, 0x1061000f, 0x10610010, 0x1062000f, 0x10620010, 0x1063000f, 0x10630010, 0x1064000f, 0x10640010, 0x1065000f, 0x10650010, 0x1066000f, 0x10660010, 0x1067000f, 0x10670010, 0x1068000f, 0x10680010, 0x1069000f, 0x10690010, 0x106a000f, 0x106a0010, 0x106b000f, 0x106b0010, 0x106c000f, 0x106c0010, 0x106d000f, 0x106d0010, 0x106e000f, 0x106e0010, 0x106f000f, 0x106f0010, 0x1070000f, 0x10700010, 0x1071000f, 0x10710010, 0x1072000f, 0x10720010, 0x1073000f, 0x10730010, 0x1074000f, 0x10740010, 0x1075000f, 0x10750010, 0x1076000f, 0x10760010, 0x1077000f, 0x10770010, 0x1078000f, 0x10780010, 0x1079000f, 0x10790010, 0x107a000f, 0x107a0010, 0x113e0010, 0x120d0011, 0x130a0012, 0x130a0012],
    values: [0x00000000, 0x00000000, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000007, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000005, 0x00000001, 0x00000001, 0x00000000],
    maximum: 0x130a0012
};

pub global CAPTURE_1_MAX_LENGTH: u32 = 128;
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
    let valid_start_state = (start_state - 0) * (start_state - 1) * (start_state - 20);
    assert(valid_start_state == 0, "Invalid start state");
}
    
/**
 * Constrains paths that begin in an anchored start state to begin at the start of the haystack
 * @dev anchored start states are hardcoded in this function. They are entered by crossing a
 *      start anchor (`^`), which only holds at haystack offset 0.
 *
 * @param start_state - The start state of the NFA
 * @param match_start - The start index of the match in the haystack
 */
fn check_start_anchor(start_state: Field, match_start: u32) {
    let is_anchored_start = (start_state == 20);
    assert(!is_anchored_start | (match_start == 0), "Start anchor requires match_start == 0");
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
    let accept_state_reached = (next_state - 19);
    let accept_state_reached_bool = (accept_state_reached == 0) as Field;

    // check if the haystack index is the asserted match length
    // should equal 1 since haystack_index should be 1 less than asserted_match)length
    let asserted_path_traversed = (asserted_match_length - haystack_index == 1) as Field;

    (1 - (accept_state_reached_bool * asserted_path_traversed))
}

/**
 * MessageIdRegex matching function
 * Regex: (?:\r\n|^)message-id:(<[A-Za-z0-9=@\\.\\+_-]+>)\r\n
 * @param in_haystack - The input haystack to search from
 * @param match_start - The start index in the haystack for the subarray to match from
 * @param match_length - The length of the subarray to extract from haystack
 * @param current_states - The current states of the NFA at each index in the match subarray
 * @param next_states - The next states of the NFA at each index in the match subarray
 * @param capture_group_<group>_ids - The ids of the capture groups in the match subarray
 * @param capture_group_<group>_starts - The start positions of the capture groups in the match subarray
 * @param capture_group_start_indices - The start indices of the capture groups in the match subarray
 * @return - tuple of substring captures as dictated by the regular expression
 */
pub fn regex_match<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(
    in_haystack: [u8; MAX_HAYSTACK_LEN],
    match_start: u32,
    match_length: u32,
    current_states: [Field; MAX_MATCH_LEN],
    next_states: [Field; MAX_MATCH_LEN],
    capture_group_1_id: [Field; MAX_MATCH_LEN],
    capture_group_1_start: [Field; MAX_MATCH_LEN],
    capture_group_start_indices: [Field; NUM_CAPTURE_GROUPS],
) -> (BoundedVec<u8, CAPTURE_1_MAX_LENGTH>) {
    // resize haystack 
    let haystack: [u8; MAX_MATCH_LEN] = select_subarray::<MAX_HAYSTACK_LEN, MAX_MATCH_LEN>(in_haystack, match_start, match_length);

    check_start_state(current_states[0]);
    check_start_anchor(current_states[0], match_start);
    for i in 0..MAX_MATCH_LEN-1 {
        // match length - 1 since current states should be 1 less than next states
        let in_range = (i < match_length - 1) as Field;
        let matching_states = current_states[i + 1] - next_states[i];
        assert(in_range * matching_states == 0, "Invalid Transition Input");
    }
    let mut reached_end_state = 1;
    for i in 0..MAX_MATCH_LEN {
        let active_capture_groups_at_index = [capture_group_1_id[i]];
        let active_capture_groups_starts_at_index = [capture_group_1_start[i]];
        check_transition_with_captures(
            TRANSITION_TABLE,
            haystack[i] as Field,
            current_states[i],
            next_states[i],
            active_capture_groups_at_index,
            active_capture_groups_starts_at_index,
            reached_end_state
        );
        reached_end_state = reached_end_state * check_accept_state(next_states[i], i as Field, match_length as Field);
    }
    assert(reached_end_state == 0, "Did not reach a valid end state");

    // Capture Group 1
    let capture_1 = capture_substring::<MAX_MATCH_LEN, CAPTURE_1_MAX_LENGTH, 1>(
       haystack,
       capture_group_1_id,
       capture_group_1_start,
       capture_group_start_indices[0]
    );

    (capture_1)
}


global MAX_HAYSTACK_LEN: u32 = 300;
global MAX_MATCH_LEN: u32 = 300;
