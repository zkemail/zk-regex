pub mod sparse_array;
pub mod transitions;
pub mod captures;

pub fn select_subarray<let MAX_ARRAY_LEN: u32, let MAX_SUBARRAY_LEN: u32>(
    input: [u8; MAX_ARRAY_LEN],
    start_index: u32,
    length: u32,
) -> [u8; MAX_SUBARRAY_LEN] {
    assert(MAX_SUBARRAY_LEN <= MAX_ARRAY_LEN, "Subarray length exceeds array length");

    // Safety: `__select_subarray` is unconstrained and unsafe
    let mut subarray = unsafe { __select_subarray(input, start_index, length) };
    assert(start_index + length <= MAX_ARRAY_LEN, "Subarray out of bounds");

    for i in 0..MAX_SUBARRAY_LEN {
        let shifted_index = i + start_index;
        let is_in_range = (i < length) as u32;
        let index = is_in_range * shifted_index;

        let byte = input[index];
        let masked = byte * is_in_range as u8;

        assert(masked == subarray[i], "Subarray: mismatch between input and output");
    }

    subarray
}

unconstrained fn __select_subarray<let MAX_HAYSTACK_LEN: u32, let MAX_MATCH_LEN: u32>(
    input: [u8; MAX_HAYSTACK_LEN],
    start_index: u32,
    length: u32,
) -> [u8; MAX_MATCH_LEN] {
    let mut subarray = [0; MAX_MATCH_LEN];
    for i in 0..MAX_MATCH_LEN {
        if i < length {
            subarray[i] = input[i + start_index];
        }
    }
    subarray
}
