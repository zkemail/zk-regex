pub mod sparse_array;
pub mod transitions;
pub mod captures;

pub fn select_subarray<
    let MAX_ARRAY_LEN: u32,
    let MAX_SUBARRAY_LEN: u32
>(
    input: [u8; MAX_ARRAY_LEN],
    start_index: u32,
    length: u32
) -> [u8; MAX_SUBARRAY_LEN] {
    assert(MAX_SUBARRAY_LEN <= MAX_ARRAY_LEN, "Subarray length exceeds array length");

    let mut output = unsafe { __select_subarray(input, start_index, length) };
    assert(start_index + length <= MAX_ARRAY_LEN, "Subarray out of bounds");
    for i in 0..MAX_SUBARRAY_LEN {
        let shifted_index = i + start_index;
        let is_in_range = (i < length) as Field;
        let index = is_in_range * shifted_index as Field;
        let byte = input[index];
        let masked = byte * is_in_range as u8;
        let output_byte = output[i];

        assert(masked == output[i], "Subarray: mismatch between input and output");
    }

    output
}


/**
 * Helper function to select a subarray from an array
 * @dev ONLY CALLED BY `select_subarray`
 *
 * @param array - the array to resize
 * @param match_start - the start index of the match
 * @param match_len - the length of the match
 * @return the selected subarray
 */
unconstrained pub fn __select_subarray<
    let MAX_HAYSTACK_LEN: u32,
    let MAX_MATCH_LEN: u32
>(
    haystack: [u8; MAX_HAYSTACK_LEN],
    match_start: u32,
    match_len: u32,
) -> [u8; MAX_MATCH_LEN] {
    let mut subarray = [0; MAX_MATCH_LEN];
    for i in 0..MAX_MATCH_LEN {
        if i < match_len {
            subarray[i] = haystack[i + match_start];
        }
    }
    subarray
}