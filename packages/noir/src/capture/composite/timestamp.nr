use crate::{
    capture::raw::timestamp as timestamp_regex,
    common::Sequence,
    constants::{TIMESTAMP_LEN},
};

/**
 * Extract timestamp
 *
 * @param input: input to extract timestamp from
 * @returns the timestamp given to the email by the MTA
 */
pub fn regex_match<let N: u32>(input: BoundedVec<u8, N>) -> [u8; TIMESTAMP_LEN] {
    let (sequence, found) = timestamp_regex::regex_match(input.storage());
    assert(found, "Body hash regex match failure over input");
    extract_timestamp(input, sequence.get(0))
}

/**
 * Converts an extracted unix timestamp to the numerical representation
 *
 * @param timestamp: timestamp to convert to number
 * @returns the same timestamp as a field element (cast as needed)
 */
pub fn parse_timestamp<let N: u32>(timestamp: [u8; N]) -> Field {
    let mut number: Field = 0;
    for i in 0..N {
        let byte = timestamp[N - i - 1];
        assert((0x30 <= byte) & (byte <= 0x39), "Timestamp byte is not a UTF-8 digit");
        let digit = byte as Field - 0x30;
        number += digit * 10.pow_32(i as Field);
    }
    number
}

/** 
 * Extract timestamp from input given a sequence
 *
 * @param input: input to extract timestamp from
 * @param sequence: sequence to extract timestamp from
 */
fn extract_timestamp<let INPUT_SIZE: u32>(
    input: BoundedVec<u8, INPUT_SIZE>,
    sequence: Sequence,
) -> [u8; TIMESTAMP_LEN] {
    // constrain extraction of timestamp from input given sequence
    let timestamp = unsafe { __extract_timestamp(input, sequence.index()) };
    assert(sequence.end() < input.len(), "Timestamp sequence out of input boundary");
    for i in 0..TIMESTAMP_LEN {
        let expected_byte = input.get_unchecked(sequence.index() + i) as Field;
        let byte = timestamp[i] as Field;
        assert(expected_byte == byte, "Could not properly construct timestamp array");
    }
    timestamp
}

/**
 * Unconstrained extraction of timestamp from email header
 * @dev SHOULD NOT BE USED EXCEPT FROM `extract_timestamp`
 *
 * @param input - input to extract timestamp from
 * @param index - starting index to extract timestamp from
 * @returns the timestamp given to the email by the MTA
 */
unconstrained fn __extract_timestamp<let INPUT_SIZE: u32>(
    input: BoundedVec<u8, INPUT_SIZE>,
    index: u32,
) -> [u8; TIMESTAMP_LEN] {
    let mut timestamp: [u8; TIMESTAMP_LEN] = [0; TIMESTAMP_LEN];
    for i in 0..TIMESTAMP_LEN {
        timestamp[i] = input.get_unchecked(index + i);
    }
    timestamp
}