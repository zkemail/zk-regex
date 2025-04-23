use crate::utils::sparse_array::SparseArray;

// separators for accessing values from byte/curr_state/next_state key in sparse array
global R: u32 = 257;
global R_SQUARED: u32 = R * R;

/**
 * Constrains a regex transition without captures to be valid
 *
 * @param table - a table (SHOULD BE COMPTIME) that defines valid regex state transitions
 * @param haystack_byte - the current byte in the haystack being processed in the regex match
 * @param current_state - the current state of the regex automata
 * @param next_state - the next state of the regex automata
 * @param reached_end_state - a boolean that can toggle off the constraint if end state has already been reached
 */
pub fn check_transition<let TABLE_LENGTH: u32>(
    table: SparseArray<TABLE_LENGTH, Field>,
    haystack_byte: Field,
    current_state: Field,
    next_state: Field,
    reached_end_state: Field,
) {
    let key = current_state + haystack_byte as Field * R as Field + next_state * R_SQUARED as Field;
    let transition_condition = table.get(key) - 1;
    let matched_condition = transition_condition * reached_end_state;
    assert(matched_condition == 0, "Invalid Transition");
}

/**
 * Constrains a regex transition with captures to be valid
 *
 * @param table - a table (SHOULD BE COMPTIME) that defines valid regex state transitions
 * @param haystack_byte - the current byte in the haystack being processed in the regex match
 * @param current_state - the current state of the regex automata
 * @param next_state - the next state of the regex automata
 * @param capture_group - the capture group id for the current state (id set at start and end states of capture group only)
 * @param capture_start - boolean indicated if the current state is the start of a capture group defined by capture_group
 * @param reached_end_state - a boolean that can toggle off the constraint if end state has already been reached
 */
pub fn check_transition_with_captures<let TABLE_SIZE: u32>(
    table: SparseArray<TABLE_SIZE, Field>,
    haystack_byte: Field,
    current_state: Field,
    next_state: Field,
    capture_group: Field,
    capture_start: Field,
    reached_end_state: Field,
) {
    let key = current_state + haystack_byte as Field * R as Field + next_state * R_SQUARED as Field;
    let (is_valid, is_capture_start, capture_id) = unpack_sparse_value(key, table);
    // check if the transition is valid
    let matched_condition = ((is_valid - 1)
        + ((capture_group - capture_id) * R as Field)
        + ((capture_start - is_capture_start) * R_SQUARED as Field))
        * reached_end_state;
    assert(matched_condition == 0, "Invalid Transition");
}

/**
 * Unpacks a transition lookup value
 * @dev 8 bit packed (0: valid transition, 1: start of capture group, 2-8: capture group id)
 * 
 * @return (valid, start_capture_group, capture_group_id)
 */
fn unpack_sparse_value<let TABLE_SIZE: u32>(key: Field, table: SparseArray<TABLE_SIZE, Field>) -> (Field, Field, Field) {
    // get packed value from lookup table
    let value = table.get(key);
    std::as_witness(value);

    // Safety: unpack value (unconstrained)
    let (is_valid, is_capture_start, capture_id) = unsafe { __unpack_sparse_value(value) };
    // check correct decomposition
    let recomposed_value = is_valid + is_capture_start * 2 + capture_id * 4;
    assert(recomposed_value == value, "Invalid Table Unpacking");

    // constrain size of values
    is_valid.assert_max_bit_size::<1>();
    is_capture_start.assert_max_bit_size::<1>();
    capture_id.assert_max_bit_size::<6>();

    // return the unpacked values
    (is_valid, is_capture_start, capture_id)
}

/**
 * Helper function to unpack a transition lookup value
 * @dev SHOULD ONLY BE CALLED BY `unpack_sparse_value`
 *
 * @param value - a byte packed with the values
 * @return (valid, start_capture_group, capture_group_id)
 */
fn __unpack_sparse_value(value: Field) -> (Field, Field, Field) {
    let x = value as u8;
    let is_valid = x & 1;
    let is_capture_start = (x & 2) >> 1;
    let capture_id = x >> 2;
    (is_valid as Field, is_capture_start as Field, capture_id as Field)
}

