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
pub fn check_transition_with_captures<let TABLE_SIZE: u32, let NUM_CAPTURE_GROUPS: u32>(
    table: SparseArray<TABLE_SIZE, Field>,
    haystack_byte: Field,
    current_state: Field,
    next_state: Field,
    capture_participations: [Field; NUM_CAPTURE_GROUPS],
    capture_starts: [Field; NUM_CAPTURE_GROUPS],
    reached_end_state: Field,
) {
    let key = current_state + haystack_byte as Field * R as Field + next_state * R_SQUARED as Field;

    let (is_valid, capture_starts_from_table, capture_participations_from_table) =
        unpack_sparse_value::<TABLE_SIZE, NUM_CAPTURE_GROUPS>(key, table);

    let mut error_accumulator: Field = 1 - is_valid;
    let base_weight: Field = 3;
    let mut current_power_of_base: Field = base_weight;
    for i in 0..NUM_CAPTURE_GROUPS {
        let capture_participations_is_set = (capture_participations[i] != 0) as Field;
        let capture_starts_is_set = (capture_starts[i] != 0) as Field;

        let participation_difference =
            capture_participations_is_set - capture_participations_from_table[i];
        error_accumulator += participation_difference * current_power_of_base;
        current_power_of_base = current_power_of_base * base_weight;

        let start_difference = capture_starts_is_set - capture_starts_from_table[i];
        error_accumulator += start_difference * current_power_of_base;
        current_power_of_base = current_power_of_base * base_weight;
    }
    let matched_condition = error_accumulator * reached_end_state;
    assert(matched_condition == 0, "Invalid Transition or Capture State Mismatch");
}

/**
 * Unpacks a transition lookup value
 * @dev 8 bit packed (0: valid transition, 1: start of capture group, 2-8: capture group id)
 * 
 * @return (valid, start_capture_group, capture_group_id)
 */
fn unpack_sparse_value<let TABLE_SIZE: u32, let NUM_CAPTURE_GROUPS: u32>(
    key: Field,
    table: SparseArray<TABLE_SIZE, Field>,
) -> (Field, [Field; NUM_CAPTURE_GROUPS], [Field; NUM_CAPTURE_GROUPS]) {
    // get packed value from lookup table
    let value = table.get(key);
    std::as_witness(value);

    // Safety: These values need to be unconstrained
    let (is_valid, is_capture_starts, capture_participations) =
        unsafe { __unpack_sparse_value(value) };

    let mut recomposed_value = is_valid;
    for i in 0..NUM_CAPTURE_GROUPS {
        let start_bit_value = (1 << (i + 1) as u8) as Field;
        recomposed_value += is_capture_starts[i] * start_bit_value;
    }
    for i in 0..NUM_CAPTURE_GROUPS {
        let participation_bit_position = (i + NUM_CAPTURE_GROUPS + 1) as u8;
        let participation_bit_value = (1 << participation_bit_position) as Field;
        recomposed_value += capture_participations[i] * participation_bit_value;
    }
    assert(recomposed_value == value, "Invalid Table Unpacking");

    // constrain size of values
    is_valid.assert_max_bit_size::<1>();
    for i in 0..NUM_CAPTURE_GROUPS {
        is_capture_starts[i].assert_max_bit_size::<1>();
        capture_participations[i].assert_max_bit_size::<1>();
    }

    // return the unpacked values
    (is_valid, is_capture_starts, capture_participations)
}

/**
 * Helper function to unpack a transition lookup value
 * @dev SHOULD ONLY BE CALLED BY `unpack_sparse_value`
 *
 * @param value - a byte packed with the values
 * @return (valid, start_capture_group, capture_group_id)
 */
unconstrained fn __unpack_sparse_value<let NUM_CAPTURE_GROUPS: u32>(
    value: Field,
) -> (Field, [Field; NUM_CAPTURE_GROUPS], [Field; NUM_CAPTURE_GROUPS]) {
    let x = value as u64;
    let is_valid = (x & 1) as Field;

    let mut masks = [0; 2 * NUM_CAPTURE_GROUPS];
    let mut is_capture_starts = [0; NUM_CAPTURE_GROUPS];
    let mut capture_participations = [0; NUM_CAPTURE_GROUPS];

    for i in 0..2 * NUM_CAPTURE_GROUPS {
        masks[i] = (1 << (i + 1) as u8);
    }

    for i in 0..NUM_CAPTURE_GROUPS {
        is_capture_starts[i] = ((x & masks[i]) >> (i + 1) as u8) as Field;
        capture_participations[i] =
            ((x & masks[NUM_CAPTURE_GROUPS + i]) >> (i + NUM_CAPTURE_GROUPS + 1) as u8) as Field;
    }

    (is_valid, is_capture_starts, capture_participations)
}
