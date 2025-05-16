use crate::utils::{
   select_subarray,
   captures::capture_substring,
   sparse_array::SparseArray,
   transitions::check_transition_with_captures
};

global TRANSITION_TABLE: SparseArray<155, Field> = SparseArray {
    keys: [0x00000000, 0x0002110f, 0x00021110, 0x0003100f, 0x00047571, 0x00047574, 0x00056f6e, 0x00067f7e, 0x00078180, 0x00087170, 0x00097978, 0x000a7978, 0x000b4342, 0x000c8180, 0x000d7e7d, 0x000e5655, 0x000f5a59, 0x00104b4a, 0x00104b4b, 0x00104d4c, 0x00104d4d, 0x00104e4d, 0x00104e4e, 0x0010504f, 0x00105050, 0x00105150, 0x00105151, 0x00105251, 0x00105252, 0x00105352, 0x00105353, 0x00105453, 0x00105454, 0x00105554, 0x00105555, 0x00105655, 0x00105656, 0x00105756, 0x00105757, 0x00105857, 0x00105858, 0x00105958, 0x00105959, 0x00105d5c, 0x00105d5d, 0x0010605f, 0x00106060, 0x00106160, 0x00106161, 0x00106261, 0x00106262, 0x00106362, 0x00106363, 0x00106463, 0x00106464, 0x00106564, 0x00106565, 0x00106665, 0x00106666, 0x00106766, 0x00106767, 0x00106867, 0x00106868, 0x00106968, 0x00106969, 0x00106a69, 0x00106a6a, 0x00106b6a, 0x00106b6b, 0x00106c6b, 0x00106c6c, 0x00106d6c, 0x00106d6d, 0x00106e6d, 0x00106e6e, 0x00106f6e, 0x00106f6f, 0x0010706f, 0x00107070, 0x00107170, 0x00107171, 0x00107271, 0x00107272, 0x00107372, 0x00107373, 0x00107473, 0x00107474, 0x00107574, 0x00107575, 0x00107675, 0x00107676, 0x00107776, 0x00107777, 0x00107877, 0x00107878, 0x00107978, 0x00107979, 0x00107a79, 0x00107a7a, 0x00107f7e, 0x00107f7f, 0x00108180, 0x00108181, 0x00108281, 0x00108282, 0x00108382, 0x00108383, 0x00108483, 0x00108484, 0x00108584, 0x00108585, 0x00108685, 0x00108686, 0x00108786, 0x00108787, 0x00108887, 0x00108888, 0x00108988, 0x00108989, 0x00108a89, 0x00108a8a, 0x00108b8a, 0x00108b8b, 0x00108c8b, 0x00108c8c, 0x00108d8c, 0x00108d8d, 0x00108e8d, 0x00108e8e, 0x00108f8e, 0x00108f8f, 0x0010908f, 0x00109090, 0x00109190, 0x00109191, 0x00109291, 0x00109292, 0x00109392, 0x00109393, 0x00109493, 0x00109494, 0x00109594, 0x00109595, 0x00109695, 0x00109696, 0x00109796, 0x00109797, 0x00109897, 0x00109898, 0x00109998, 0x00109999, 0x00109a99, 0x00109a9a, 0x0011605f, 0x00123130, 0x0013302f, 0x00c98f8d],
    values: [0x00000000, 0x00000000, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000007, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000005, 0x00000001, 0x00000001, 0x00000000],
    maximum: 0x00c98f8d
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
       capture_group_start_indices[0] - (match_start as Field),
    );

    (capture_1)
}

global MAX_HAYSTACK_LEN: u32 = 300;
global MAX_MATCH_LEN: u32 = 300;

