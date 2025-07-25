/// NOTE ON HOW `capture_ids` and `capture_starts` WORK
/// Example input:
///
///   haystack       = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
///   capture_ids    = [0, 0, 0, X, 0, 0, 0, X, 0, 0]
///   capture_starts = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
///
/// In transition logic with captures, we constrain byte / current state / next state looks up to a
/// certain packed value. This packed value contains (valid, start_capture_group, capture_group_id).
/// `capture_ids` (6 bit number indicating capture group) and `capture_starts` (binary indicating
/// start of capture group) are constrained to be correct here, so the integrity is already constrained.
///
/// There can be multiple transitions of non-deterministic paths between the start and end of a capture.
/// For `capture_ids`, we will put the id of the capture group at the index where the capture starts and
/// the index where the capture ends (in example @ index 3 and 7). Meanwhile, we will set a boolean
/// at index 3 for `capture_starts`. This is enough information to determine the start and end of the
/// capture group X (X could be 1, 63, etc):
///
///   capture_ids[3] == X && capture_starts[3] == 1 indicates start
///   capture_ids[7] == X && capture_starts[7] == 0 indicates end
///
/// The process of capturing is as follows:
/// 1. Build a bitmask `is_capture` for capture ID X, creating a new array where 1 is only set if
///    the `capture_id` value matches the expected capture group id (done by `build_is_capture`):
///
///   capture_ids = [0, 0, 0, X, 0, 0, 0, X, 0, 0]
///   is_capture  = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0]
///
/// 2. Build a bitmask `is_capture_start` - this mask looks for `is_capture[i]` to be 1 and
///    `capture_starts[i]` to be 1. All values before this is found should be masked to 0, and all values
///    from this index to the end should be masked to 1 (done by `build_capture_start_end_mask`):
///
///    is_capture       = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0]
///    capture_starts   = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
///    is_capture_start = [0, 0, 0, 1, 1, 1, 1, 1, 1, 1]
///
/// 3. Build a bitmask `is_capture_end` - this mask looks for `is_capture[i]` to be 1 and
///   `capture_starts[i]` to be 0. This check looks backwards, starting at the last index and iterates
///   backwards. All values after this is found should be masked to 0, and all values from this index
///   to the start should be masked to 1 (done by `build_capture_start_end_mask`):
///
///   is_capture     = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0]
///   capture_starts = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
///   is_capture_end = [1, 1, 1, 1, 1, 1, 1, 1, 0, 0]
///
/// 4. With `is_capture_start` and `is_capture_end`, we can take the intersection of the two masks
///    to build a final mask `capture_mask` which is constrained to reveal the exact substring we
///    want to capture (done by `__build_capture_mask`):
///
///   is_capture_start = [0, 0, 0, 1, 1, 1, 1, 1, 1, 1]
///   is_capture_end   = [1, 1, 1, 1, 1, 1, 1, 1, 0, 0]
///   capture_mask     = [0, 0, 0, 1, 1, 1, 1, 1, 0, 0]
///
/// 5. Finally, we can use the `capture_mask` to extract the substring from the haystack. This process
///    is relatively straightforward and will not be explained in depth

/**
 * Captures a substring from a haystack
 *
 * @param MAX_MATCH_LENGTH: The maximum length of the match
 * @param MAX_SUBSTRING_LENGTH: The maximum length of the captured substring
 * @param CAPTURE_GROUP: the id of the capture group to match for
 *
 * @param haystack - The haystack of bytes to capture the substring from
 * @param capture_ids - The capture group ids for the haystack (only set at start and end indices)
 * @ 
 * 
 */
pub fn capture_substring<let MAX_MATCH_LENGTH: u32, let MAX_SUBSTRING_LENGTH: u32, let CAPTURE_GROUP: Field>(
    haystack: [u8; MAX_MATCH_LENGTH],
    capture_ids: [Field; MAX_MATCH_LENGTH],
    capture_starts: [Field; MAX_MATCH_LENGTH],
    capture_start_index: Field,
) -> BoundedVec<u8, MAX_SUBSTRING_LENGTH> {
    let is_capture = build_is_capture::<MAX_MATCH_LENGTH, CAPTURE_GROUP>(capture_ids);

    let (is_capture_start, is_capture_end) =
        build_capture_start_end_mask(is_capture, capture_starts);

    // Safety: capture_mask is not constrained.
    let capture_mask = unsafe { __build_capture_mask(is_capture_start, is_capture_end) };

    for i in 0..MAX_MATCH_LENGTH {
        let expected_mask = is_capture_start[i] * is_capture_end[i];
        assert(capture_mask[i] == expected_mask, "Invalid Capture Mask");
    }

    substring_from_mask(haystack, capture_mask, capture_start_index)
}

fn build_is_capture<let MAX_MATCH_LENGTH: u32, let CAPTURE_GROUP: Field>(
    capture_ids: [Field; MAX_MATCH_LENGTH],
) -> [Field; MAX_MATCH_LENGTH] {
    // Safety: capture_ids is not constrained.
    let is_capture = unsafe { __build_is_capture::<MAX_MATCH_LENGTH, CAPTURE_GROUP>(capture_ids) };

    for i in 0..MAX_MATCH_LENGTH {
        // check is_capture is binary
        is_capture[i].assert_max_bit_size::<1>();
        // check if the capture group is targeted at index
        let index_selector = (capture_ids[i] == CAPTURE_GROUP) as Field;
        // if the index is part of the capture group, check mask
        assert(index_selector * (is_capture[i] - 1) == 0, "Invalid Capture Group Mask");
    }

    is_capture
}

fn substring_from_mask<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(
    haystack: [u8; MAX_HAYSTACK_LEN],
    mask: [Field; MAX_HAYSTACK_LEN],
    start_index: Field,
) -> BoundedVec<u8, MAX_MATCH_LEN> {
    // Safety: substring is not constrained.
    let substring = unsafe { __substring_from_mask(haystack, mask, start_index) };

    let start_index_is_zero = (start_index == 0) as Field;
    let start_index_to_check = (start_index - (1 - start_index_is_zero)) as u32;
    let preceding_mask_value = mask[start_index_to_check];
    let preceding_mask_check =
        start_index_is_zero + ((1 - start_index_is_zero) * (1 - preceding_mask_value));
    assert(
        preceding_mask_check == 1,
        "Invalid substring start index: preceding mask value is not 0",
    );

    let mut length = 0;
    for i in 0..MAX_MATCH_LEN {
        let index = start_index as u32 + i;
        if index < MAX_HAYSTACK_LEN {
            let mask_value = mask[index];
            let haystack_value = haystack[index] as Field;
            let substring_value = substring.get_unchecked(i) as Field;
            assert(mask_value * haystack_value == substring_value, "Invalid substring extraction");
            length += mask_value;
        }
    }
    assert(length != 0, "Invalid substring length");
    assert(substring.len() as Field == length, "Invalid substring length");

    let end_index_plus_1 = start_index + length;
    let end_index_is_max = (end_index_plus_1 == MAX_HAYSTACK_LEN as Field) as Field;
    let end_index_to_check = (
        ((1 - end_index_is_max) * end_index_plus_1) + end_index_is_max * (end_index_plus_1 - 1)
    ) as u32;
    let following_mask_value = mask[end_index_to_check];
    let following_mask_check =
        end_index_is_max + ((1 - end_index_is_max) * (1 - following_mask_value));
    assert(following_mask_check == 1, "Invalid substring end index: proceding mask value is not 0");

    assert(
        mask[end_index_to_check - 1] == 1,
        "Invalid substring end index: end index mask value is not 1",
    );

    substring
}

fn build_capture_start_end_mask<let MAX_MATCH_LENGTH: u32>(
    is_capture: [Field; MAX_MATCH_LENGTH],
    capture_starts: [Field; MAX_MATCH_LENGTH],
) -> ([Field; MAX_MATCH_LENGTH], [Field; MAX_MATCH_LENGTH]) {
    // Safety: start and end masks are not constrained.
    let (start_mask, end_mask) =
        unsafe { __build_capture_start_end_mask(is_capture, capture_starts) };

    let is_capture_start_temp = (capture_starts[0] - 1 == 0) as Field;
    let expected_start_mask = ((is_capture[0] * is_capture_start_temp) == 1) as Field;
    assert(start_mask[0] == expected_start_mask, "Invalid Capture Start Mask");

    let is_capture_end_temp = (capture_starts[MAX_MATCH_LENGTH - 1] == 0) as Field;
    let expected_end_mask = (is_capture[MAX_MATCH_LENGTH - 1] * is_capture_end_temp == 1) as Field;
    assert(end_mask[MAX_MATCH_LENGTH - 1] == expected_end_mask, "Invalid Capture End Mask");

    for i in 1..MAX_MATCH_LENGTH {
        let is_capture_start_temp = (capture_starts[i] - 1 == 0) as Field;
        let is_capture_start_valid_temp = ((is_capture[i] * is_capture_start_temp) == 1) as Field;
        let expected_start_mask =
            (1 - (1 - is_capture_start_valid_temp) * (1 - start_mask[i - 1]) == 1) as Field;
        assert(start_mask[i] == expected_start_mask, "Invalid Capture Start Mask");

        let j = MAX_MATCH_LENGTH - 1 - i;
        let is_capture_end_temp = (capture_starts[j] == 0) as Field;
        let is_capture_end_valid_temp = (is_capture[j] * is_capture_end_temp == 1) as Field;
        let expected_end_mask =
            (1 - (1 - is_capture_end_valid_temp) * (1 - end_mask[j + 1]) == 1) as Field;
        assert(end_mask[j] == expected_end_mask, "Invalid Capture End Mask");
    }
    (start_mask, end_mask)
}

unconstrained fn __build_is_capture<let MAX_MATCH_LENGTH: u32, let CAPTURE_GROUP: Field>(
    capture_ids: [Field; MAX_MATCH_LENGTH],
) -> [Field; MAX_MATCH_LENGTH] {
    let mut is_capture = [0; MAX_MATCH_LENGTH];
    for i in 0..MAX_MATCH_LENGTH {
        is_capture[i] = (capture_ids[i] == CAPTURE_GROUP) as Field;
    }
    is_capture
}

unconstrained fn __build_capture_mask<let MAX_MATCH_LENGTH: u32>(
    capture_start_mask: [Field; MAX_MATCH_LENGTH],
    capture_end_mask: [Field; MAX_MATCH_LENGTH],
) -> [Field; MAX_MATCH_LENGTH] {
    let mut capture_mask = [0; MAX_MATCH_LENGTH];
    for i in 0..MAX_MATCH_LENGTH {
        capture_mask[i] = capture_start_mask[i] * capture_end_mask[i];
    }

    capture_mask
}

unconstrained fn __build_capture_start_end_mask<let MAX_MATCH_LENGTH: u32>(
    is_capture: [Field; MAX_MATCH_LENGTH],
    capture_starts: [Field; MAX_MATCH_LENGTH],
) -> ([Field; MAX_MATCH_LENGTH], [Field; MAX_MATCH_LENGTH]) {
    let mut capture_start_mask = [0; MAX_MATCH_LENGTH];
    let mut capture_end_mask = [0; MAX_MATCH_LENGTH];

    let is_capture_start_temp = (capture_starts[0] - 1 == 0) as Field;
    capture_start_mask[0] = ((is_capture[0] * is_capture_start_temp) == 1) as Field;

    let is_capture_end_temp = (capture_starts[MAX_MATCH_LENGTH - 1] == 0) as Field;
    capture_end_mask[MAX_MATCH_LENGTH - 1] =
        (is_capture[MAX_MATCH_LENGTH - 1] * is_capture_end_temp == 1) as Field;

    for i in 1..MAX_MATCH_LENGTH {
        let is_capture_start_temp = (capture_starts[i] - 1 == 0) as Field;
        let is_capture_start_valid_temp = ((is_capture[i] * is_capture_start_temp) == 1) as Field;
        capture_start_mask[i] =
            (1 - (1 - is_capture_start_valid_temp) * (1 - capture_start_mask[i - 1]) == 1) as Field;

        let j = MAX_MATCH_LENGTH - 1 - i;
        let is_capture_end_temp = (capture_starts[j] == 0) as Field;
        let is_capture_end_valid_temp = (is_capture[j] * is_capture_end_temp == 1) as Field;
        capture_end_mask[j] =
            (1 - (1 - is_capture_end_valid_temp) * (1 - capture_end_mask[j + 1]) == 1) as Field;
    }
    (capture_start_mask, capture_end_mask)
}

unconstrained fn __substring_from_mask<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(
    haystack: [u8; MAX_HAYSTACK_LEN],
    mask: [Field; MAX_HAYSTACK_LEN],
    start_index: Field,
) -> BoundedVec<u8, MAX_MATCH_LEN> {
    let mut substring = BoundedVec::new();
    for i in 0..MAX_MATCH_LEN {
        let index = start_index as u32 + i;
        if index < MAX_HAYSTACK_LEN {
            let mask_value = mask[index];
            if mask_value == 1 {
                substring.push(haystack[index]);
            }
        } else {
            break;
        }
    }
    substring
}
