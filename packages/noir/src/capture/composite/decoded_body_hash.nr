use crate::{
    capture::raw::body_hash,
    common::Sequence,
    constants::{BODY_HASH_BASE64_LEN, BODY_HASH_LEN},
};
use base64::BASE64_DECODER;

/**
 * Extract body hash from input given a sequence using regex match and capture
 * @dev function performs base64 decoding and returns exact array length since length always the same
 *
 * @param input: input to extract body hash from
 * @returns the extracted body hash after base64 decoding
 */
pub fn regex_match<let N: u32>(input: BoundedVec<u8, N>) -> [u8; BODY_HASH_LEN] {
    let (sequence, found) = body_hash::regex_match(input.storage());
    assert(found, "Body hash regex match failure over input");
    extract_body_hash(input, sequence.get(0))
}

/** 
 * Extract body hash from input given a sequence
 *
 * @param input: input to extract body hash from
 * @param bh_sequence: sequence to extract body hash from
 */
fn extract_body_hash<let INPUT_SIZE: u32>(
    input: BoundedVec<u8, INPUT_SIZE>,
    sequence: Sequence,
) -> [u8; BODY_HASH_LEN] {
    // constrain extraction of body hash from input given sequence
    let encoded_body_hash = unsafe { __extract_encoded_body_hash(input, sequence.index()) };
    assert(sequence.end() < input.len(), "Body hash sequence out of input boundary");
    for i in 0..BODY_HASH_BASE64_LEN {
        let expected_byte = input.get_unchecked(sequence.index() + i) as Field;
        let byte = encoded_body_hash[i] as Field;
        assert(expected_byte == byte, "Could not properly construct body hash array");
    }
    // base64 decode body hash
    BASE64_DECODER.decode(encoded_body_hash)
}

/**
 * Unconstrained extraction of b64-encoded body hash sequence given starting index and input to extract from
 * @dev SHOULD NOT BE USED EXCEPT FROM `extract_body_hash`
 *
 * @param input - input to extract body hash from
 * @param index - starting index to extract body hash from
 * @returns the b64-encoded body hash sequence
 */
unconstrained fn __extract_encoded_body_hash<let INPUT_SIZE: u32>(
    input: BoundedVec<u8, INPUT_SIZE>,
    index: u32
) -> [u8; BODY_HASH_BASE64_LEN] {
    let mut body_hash_encoded: [u8; BODY_HASH_BASE64_LEN] = [0; BODY_HASH_BASE64_LEN];
    for i in 0..BODY_HASH_BASE64_LEN {
        body_hash_encoded[i] = input.get_unchecked(index + i);
    }
    body_hash_encoded
}