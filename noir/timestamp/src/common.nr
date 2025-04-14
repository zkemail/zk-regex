use sort::sort_advanced;

pub global R: u32 = 257;
pub global R_SQUARED: u32 = R * R;

unconstrained fn __sort_field_as_u32(lhs: Field, rhs: Field) -> bool {
    //  lhs.lt(rhs)
    lhs as u32 <= rhs as u32
}
pub struct SparseArray<let N: u32, T> {
    pub keys: [Field; N + 2],
    pub values: [T; N + 3],
    pub  maximum: Field, // can be up to 2^32
}

fn assert_sorted(lhs: Field, rhs: Field) {
    let result = (rhs - lhs - 1);
    result.assert_max_bit_size::<32>();
}

/// Note: excisting SparseArray impl has a small bug, local impl until fixed
pub impl<let N: u32, T> SparseArray<N, T>
where
    T: std::default::Default,
{

    /**
     * @brief construct a SparseArray
     **/
    pub fn create(_keys: [Field; N], _values: [T; N], size: Field) -> Self {
        let _maximum = size - 1;
        let mut r: Self =
            SparseArray { keys: [0; N + 2], values: [T::default(); N + 3], maximum: _maximum };

        // for any valid index, we want to ensure the following is satified:
        // self.keys[X] <= index <= self.keys[X+1]
        // this requires us to sort hte keys, and insert a startpoint and endpoint
        let sorted_keys = sort_advanced(_keys, __sort_field_as_u32, assert_sorted);

        // insert start and endpoints
        r.keys[0] = 0;
        for i in 0..N {
            r.keys[i + 1] = sorted_keys.sorted[i];
        }
        r.keys[N + 1] = _maximum;

        // populate values based on the sorted keys
        // note: self.keys[i] maps to self.values[i+1]
        // self.values[0] does not map to any key. we use it to store the default empty value,
        // which is returned when `get(idx)` is called and `idx` does not exist in `self.keys`
        for i in 0..N {
            // if (sorted_keys.sorted[i] == 0x0d)
            // {
            //     let x = sorted_keys.sort_indices[i];
            //     let y = _values[sorted_keys.sort_indices[i]];
            //     println(f"i = {i}, sort indices = {x}, value? = {y}");
            //     assert(x == -1);
            // }
            // THIS IS THE BUG: the commented line was the original line
            r.values[sorted_keys.sort_indices[i] + 2] = _values[i];
        //    r.values[i + 2] = _values[sorted_keys.sort_indices[i]];
        }
        // insert values that map to our key start and endpoints
        // if _keys[0] = 0 then values[0] must equal _values[0], so some conditional logic is required
        // (same for _keys[N-1])
        let mut initial_value = T::default();
        if (_keys[0] == 0) {
            initial_value = _values[0];
        }
        let mut final_value = T::default();
        if (_keys[N - 1] == _maximum) {
            final_value = _values[N - 1];
        }
        r.values[1] = initial_value;
        r.values[N + 2] = final_value;

        // perform boundary checks!
        // the maximum size of the sparse array is 2^32
        // we need to check that every element in `self.keys` is less than 2^32
        // because `self.keys` is sorted, we can simply validate that
        // sorted_keys.sorted[0] < 2^32
        // sorted_keys.sorted[N-1] < maximum
        sorted_keys.sorted[0].assert_max_bit_size::<32>();
        _maximum.assert_max_bit_size::<32>();
        (_maximum - sorted_keys.sorted[N - 1]).assert_max_bit_size::<32>();
        r
    }

    /**
     * @brief determine whether `target` is present in `self.keys`
     * @details if `found == false`, `self.keys[found_index] < target < self.keys[found_index + 1]`
     **/
    unconstrained fn search_for_key(self, target: Field) -> (Field, Field) {
        let mut found = false;
        let mut found_index = 0;
        let mut previous_less_than_or_equal_to_target = false;
        for i in 0..N + 2 {
            // if target = 0xffffffff we need to be able to add 1 here, so use u64
            let current_less_than_or_equal_to_target = self.keys[i] as u64 <= target as u64;
            if (self.keys[i] == target) {
                found = true;
                found_index = i as Field;
                break;
            }
            if (previous_less_than_or_equal_to_target & !current_less_than_or_equal_to_target) {
                found_index = i as Field - 1;
                break;
            }
            previous_less_than_or_equal_to_target = current_less_than_or_equal_to_target;
        }
        (found as Field, found_index)
    }

    /**
     * @brief return element `idx` from the sparse array
     * @details cost is 14.5 gates per lookup
     **/
    pub fn get(self, idx: Field) -> T {
        let (found, found_index) = unsafe { self.search_for_key(idx) };
        // bool check. 0.25 gates cheaper than a raw `bool` type. need to fix at some point
        assert(found * found == found);

        // OK! So we have the following cases to check
        // 1. if `found` then `self.keys[found_index] == idx`
        // 2. if `!found` then `self.keys[found_index] < idx < self.keys[found_index + 1]
        // how do we simplify these checks?
        // case 1 can be converted to `self.keys[found_index] <= idx <= self.keys[found_index]
        // case 2 can be modified to  `self.keys[found_index] + 1 <= idx <= self.keys[found_index + 1] - 1
        // combine the two into the following single statement:
        // `self.keys[found_index] + 1 - found <= idx <= self.keys[found_index + 1 - found] - 1 + found
        let lhs = self.keys[found_index];
        let rhs = self.keys[found_index + 1 - found];
        let lhs_condition = idx - lhs - 1 + found;
        let rhs_condition = rhs - 1 + found - idx;
        lhs_condition.assert_max_bit_size::<32>();
        rhs_condition.assert_max_bit_size::<32>();

        // self.keys[i] maps to self.values[i+1]
        // however...if we did not find a non-sparse entry, we want to return self.values[0] (the default value)
        let value_index = (found_index + 1) * found;
        self.values[value_index]
    }
}


pub fn capture_substring<let HAYSTACK_MAX_LENGTH: u32, let MATCH_MAX_LEN: u32, let CAPTURE_GROUP: Field>(
    haystack: [u8; HAYSTACK_MAX_LENGTH],
    capture_ids: [Field; HAYSTACK_MAX_LENGTH],
    capture_starts: [Field; HAYSTACK_MAX_LENGTH],
    capture_start_index: Field,
) -> BoundedVec<u8, MATCH_MAX_LEN> {
    // capture substring
    let mut is_capture_start = [0; HAYSTACK_MAX_LENGTH];
    let mut is_capture_end = [0; HAYSTACK_MAX_LENGTH];

    // determine if an index is the start or end of the capture group
    let is_capture = build_is_capture::<HAYSTACK_MAX_LENGTH, CAPTURE_GROUP>(capture_ids);
    // build start and end masks
    let (is_capture_start, is_capture_end) =
        unsafe { __build_capture_start_end_mask(is_capture, capture_starts) };
    
    // build capture mask
    let capture_mask = unsafe { __build_capture_mask(is_capture_start, is_capture_end) };
    for i in 0..HAYSTACK_MAX_LENGTH {
        let expected_mask = is_capture_start[i] * is_capture_end[i];
        assert(capture_mask[i] == expected_mask, "Invalid Capture Mask");
    }
    // extract the substring
    substring_from_mask(haystack, capture_mask, capture_start_index)
}


/**
 * Unpacks a transition lookup value
 * @dev 8 bit packed (0: valid transition, 1: start of capture group, 2-8: capture group id)
 * 
 * @return (valid, start_capture_group, capture_group_id)
 */
fn unpack_sparse_value<let TABLE_SIZE: u32>(key: Field, table: SparseArray<TABLE_SIZE, Field>) -> (Field, Field, Field) {
    let value = table.get(key);
    std::as_witness(value);
    let (is_valid, is_capture_start, capture_id) = unsafe { __unpack_sparse_value(value) };
    is_valid.assert_max_bit_size::<1>();
    is_capture_start.assert_max_bit_size::<1>();
    capture_id.assert_max_bit_size::<6>();
    (is_valid, is_capture_start, capture_id)
}

fn __unpack_sparse_value(value: Field) -> (Field, Field, Field) {
    let x = value as u8;
    let is_valid = x & 1;
    let is_capture_start = (x & 2) >> 1;
    let capture_id = x >> 2;
    (is_valid as Field, is_capture_start as Field, capture_id as Field)
}
        
pub fn check_transition_with_captures<let TABLE_SIZE: u32>(
    haystack_byte: Field,
    current_state: Field,
    next_state: Field,
    asserted_capture_group: Field,
    asserted_capture_start: Field,
    reached_end_state: Field,
    table: SparseArray<TABLE_SIZE, Field>
) {
    let key = current_state + haystack_byte as Field * R as Field + next_state * R_SQUARED as Field;
    let (is_valid, is_capture_start, capture_id) = unpack_sparse_value(key, table);
    // check if the transition is valid
    let matched_condition = ((is_valid - 1)
        + ((asserted_capture_group - capture_id) * R as Field)
        + ((asserted_capture_start - is_capture_start) * R_SQUARED as Field))
        * reached_end_state;
    assert(matched_condition == 0, "Invalid Transition");
}

pub fn check_transition<let TABLE_LENGTH: u32>(
    haystack_byte: Field,
    current_state: Field,
    next_state: Field,
    reached_end_state: Field,
    table: SparseArray<TABLE_LENGTH, Field>
) {
    let key = current_state + haystack_byte as Field * R as Field + next_state * R_SQUARED as Field;
    let transition_condition = table.get(key) - 1;
    let matched_condition = transition_condition * reached_end_state;
    assert(matched_condition == 0, "Invalid Transition");
}

/**
 * Build a capture mask for the capture group
 *
 * @param capture_start_mask - The mask of capture starts for the group
 * @return - a mask representing the capture group
 */
fn build_is_capture<let HAYSTACK_MAX_LENGTH: u32, let CAPTURE_GROUP: Field>(
    capture_ids: [Field; HAYSTACK_MAX_LENGTH],
) -> [Field; HAYSTACK_MAX_LENGTH] {
    let is_capture =
        unsafe { __build_is_capture::<HAYSTACK_MAX_LENGTH, CAPTURE_GROUP>(capture_ids) };
    for i in 0..HAYSTACK_MAX_LENGTH {
        // check is_capture is binary
        let is_capture_temp = is_capture[i];
        is_capture_temp.assert_max_bit_size::<1>();

        // check if the capture group is targeted at index
        let capture_id = capture_ids[i];
        std::as_witness(capture_id);
        let index_selector = (capture_id - CAPTURE_GROUP == 0) as Field;

        // if the index is part of the capture group, check mask
        assert(index_selector * (capture_id - CAPTURE_GROUP) == 0, "Invalid Capture Group Mask");
    }
    is_capture
}

/**
 * Helper function to build a is_capture bitmask without dynamic arrays
 * @dev HELPER FOR `build_is_capture_mask` - DO NOT CALL OUTSIDE OF THIS FUNCTION
 *
 * @param capture_ids - The (previously constrained) capture group ids for the haystack
 * @return - a mask representing the capture group
 */
unconstrained fn __build_is_capture<let HAYSTACK_MAX_LENGTH: u32, let CAPTURE_GROUP: Field>(
    capture_ids: [Field; HAYSTACK_MAX_LENGTH],
) -> [Field; HAYSTACK_MAX_LENGTH] {
    let mut is_capture = [0; HAYSTACK_MAX_LENGTH];
    for i in 0..HAYSTACK_MAX_LENGTH {
        is_capture[i] = (capture_ids[i] - CAPTURE_GROUP == 0) as Field;
    }
    is_capture
}

/**
 * Helper function to build a capture mask without dynamic arrays
 * @dev HELPER FOR `capture_substring` - DO NOT CALL OUTSIDE OF THIS FUNCTION
 *
 * @param capture_start_mask - The mask of capture starts for the group
 * @param capture_end_mask - The mask of capture ends for the group
 * @return - a mask representing the union of the two masks
 */
unconstrained fn __build_capture_mask<let HAYSTACK_MAX_LENGTH: u32>(
    capture_start_mask: [Field; HAYSTACK_MAX_LENGTH],
    capture_end_mask: [Field; HAYSTACK_MAX_LENGTH],
) -> [Field; HAYSTACK_MAX_LENGTH] {
    let mut capture_mask = [0; HAYSTACK_MAX_LENGTH];
    for i in 0..HAYSTACK_MAX_LENGTH {
        capture_mask[i] = capture_start_mask[i] * capture_end_mask[i];
    }

    capture_mask
}

/**
 * Extracts a substring from the haystack using a mask created from capture group ids
 *
 * @param haystack - The haystack of bytes to reveal substring from
 * @param mask - the capture group mask constructed to extract the substring
 * @param start_index - the asserted start index of the substring
 * @return - the substring extracted as a bounded vec
 */
fn substring_from_mask<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(
    haystack: [u8; MAX_HAYSTACK_LEN],
    mask: [Field; MAX_HAYSTACK_LEN],
    start_index: Field,
) -> BoundedVec<u8, MAX_MATCH_LEN> {
    let substring = unsafe { __substring_from_mask(haystack, mask, start_index) };
    let mut length = 0;
    for i in 0..MAX_MATCH_LEN {
        let index = start_index + i as Field;
        let mask_value = mask[index];
        let haystack_value = haystack[index] as Field;
        let substring_value = substring.get_unchecked(i) as Field;
        assert(mask_value * haystack_value == substring_value, "Invalid substring extraction");
        length += mask_value;
    }
    assert(substring.len() as Field == length, "Invalid substring length");
    substring
}

/**
 * Unconstrained construction of substring bounded vec
 * @dev HELPER FOR `substring_from_mask` - DO NOT CALL OUTSIDE OF THIS FUNCTION
 * @todo: check the asserted index is correct?
 *
 * @param haystack - The haystack of bytes to reveal substring from
 * @param mask - the capture group mask constructed to extract the substring
 * @param start_index - the asserted start index of the substring
 * @return - the substring extracted as a bounded vec
 */
unconstrained fn __substring_from_mask<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(
    haystack: [u8; MAX_HAYSTACK_LEN],
    mask: [Field; MAX_HAYSTACK_LEN],
    start_index: Field,
) -> BoundedVec<u8, MAX_MATCH_LEN> {
    let mut substring = BoundedVec::new();
    for i in 0..MAX_MATCH_LEN {
        let index = start_index + i as Field;
        let mask_value = mask[index];
        if mask_value == 1 {
            substring.push(haystack[index]);
        }
    }
    substring
}

unconstrained fn __build_capture_start_end_mask<let HAYSTACK_MAX_LENGTH: u32>(
    is_capture: [Field; HAYSTACK_MAX_LENGTH],
    capture_starts: [Field; HAYSTACK_MAX_LENGTH],
) -> ([Field; HAYSTACK_MAX_LENGTH], [Field; HAYSTACK_MAX_LENGTH]) {
    let mut capture_start_mask = [0; HAYSTACK_MAX_LENGTH];
    let mut capture_end_mask = [0; HAYSTACK_MAX_LENGTH];
    // first capture group start
    let is_capture_start_temp = (capture_starts[0] - 1 == 0) as Field;
    capture_start_mask[0] = ((is_capture[0] * is_capture_start_temp) == 1) as Field;

    // last capture group end
    let is_capture_end_temp = (capture_starts[HAYSTACK_MAX_LENGTH - 1] == 0) as Field;
    capture_end_mask[HAYSTACK_MAX_LENGTH - 1] =
        (is_capture[HAYSTACK_MAX_LENGTH - 1] * is_capture_end_temp == 1) as Field;

    for i in 1..HAYSTACK_MAX_LENGTH {
        // capture group start
        let is_capture_start_temp = (capture_starts[i] - 1 == 0) as Field;
        let is_capture_start_valid_temp = ((is_capture[i] * is_capture_start_temp) == 1) as Field;
        capture_start_mask[i] =
            (1 - (1 - is_capture_start_valid_temp) * (1 - capture_start_mask[i - 1]) == 1) as Field;

        // capture group end
        let j = HAYSTACK_MAX_LENGTH - 1 - i;
        let is_capture_end_temp = (capture_starts[j] == 0) as Field;
        let is_capture_end_valid_temp = (is_capture[j] * is_capture_end_temp == 1) as Field;
        capture_end_mask[j] =
            (1 - (1 - is_capture_end_valid_temp) * (1 - capture_end_mask[j + 1]) == 1) as Field;
    }
    (capture_start_mask, capture_end_mask)
}
