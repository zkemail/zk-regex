use zkregex::common::timestamp_regex::{
    CAPTURE_1_MAX_LENGTH,
    NUM_CAPTURE_GROUPS,
    regex_match
};
use zkemail::{
    dkim::RSAPubkey,
    headers::body_hash::get_body_hash,
    KEY_LIMBS_2048,
    Sequence
};
use sha256::sha256_var;
use std::hash::pedersen_hash;

global MAX_EMAIL_HEADER_LENGTH: u32 = 512;
global MAX_EMAIL_BODY_LENGTH: u32 = 1024;
global MAX_MATCH_LEN: u32 = 100;

fn main(
    // email inputs
    header: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>,
    body: BoundedVec<u8, MAX_EMAIL_BODY_LENGTH>,
    pubkey: RSAPubkey<KEY_LIMBS_2048>,
    signature: [Field; KEY_LIMBS_2048],
    body_hash_index: u32,
    dkim_header_sequence: Sequence,
    // regex inputs
    match_start: u32,
    match_length: u32,
    curr_states: [Field; MAX_MATCH_LEN],
    next_states: [Field; MAX_MATCH_LEN],        
    capture_group_ids: [Field; MAX_MATCH_LEN],
    capture_group_starts: [Field; MAX_MATCH_LEN],
    capture_group_start_indices: [Field; NUM_CAPTURE_GROUPS],
) -> pub (Field, Field, BoundedVec<u8, CAPTURE_1_MAX_LENGTH>) {
    // verify dkim signature
    pubkey.verify_dkim_signature(header, signature);

    // extract signed body hash & b64 decode
    let signed_body_hash = get_body_hash(header, dkim_header_sequence, body_hash_index);

    // hash the asserted body
    let computed_body_hash: [u8; 32] = sha256_var(body.storage(), body.len() as u64);

    // compare the body hashes
    assert(
        signed_body_hash == computed_body_hash,
        "SHA256 hash computed over body does not match body hash found in DKIM-signed header",
    );

    // create email nullifier and dkim key hash
    let email_nullifier = pedersen_hash(signature);
    let pubkey_hash = pubkey.hash();
    // regex matching
    let timestamp_substring = regex_match(
        header.storage(),
        match_start,
        match_length,
        curr_states,
        next_states,
        capture_group_ids,
        capture_group_starts,
        capture_group_start_indices,
    );

    (pubkey_hash, email_nullifier, timestamp_substring)
}

// #[test]
// fn test_regex() {
//     let in_haystack = [
//         102, 114, 111, 109, 58, 114, 117, 110, 110, 105, 101, 114, 46, 108, 101, 97, 103, 117, 101,
//         115, 46, 48, 106, 64, 105, 99, 108, 111, 117, 100, 46, 99, 111, 109, 13, 10, 99, 111, 110,
//         116, 101, 110, 116, 45, 116, 121, 112, 101, 58, 116, 101, 120, 116, 47, 112, 108, 97, 105,
//         110, 59, 32, 99, 104, 97, 114, 115, 101, 116, 61, 117, 115, 45, 97, 115, 99, 105, 105, 13,
//         10, 109, 105, 109, 101, 45, 118, 101, 114, 115, 105, 111, 110, 58, 49, 46, 48, 32, 40, 77,
//         97, 99, 32, 79, 83, 32, 88, 32, 77, 97, 105, 108, 32, 49, 54, 46, 48, 32, 92, 40, 51, 55,
//         51, 49, 46, 53, 48, 48, 46, 50, 51, 49, 92, 41, 41, 13, 10, 115, 117, 98, 106, 101, 99, 116,
//         58, 72, 101, 108, 108, 111, 13, 10, 109, 101, 115, 115, 97, 103, 101, 45, 105, 100, 58, 60,
//         56, 70, 56, 49, 57, 68, 51, 50, 45, 66, 54, 65, 67, 45, 52, 56, 57, 68, 45, 57, 55, 55, 70,
//         45, 52, 51, 56, 66, 66, 67, 52, 67, 65, 66, 50, 55, 64, 109, 101, 46, 99, 111, 109, 62, 13,
//         10, 100, 97, 116, 101, 58, 83, 97, 116, 44, 32, 50, 54, 32, 65, 117, 103, 32, 50, 48, 50,
//         51, 32, 49, 50, 58, 50, 53, 58, 50, 50, 32, 43, 48, 52, 48, 48, 13, 10, 116, 111, 58, 122,
//         107, 101, 119, 116, 101, 115, 116, 64, 103, 109, 97, 105, 108, 46, 99, 111, 109, 13, 10,
//         100, 107, 105, 109, 45, 115, 105, 103, 110, 97, 116, 117, 114, 101, 58, 118, 61, 49, 59, 32,
//         97, 61, 114, 115, 97, 45, 115, 104, 97, 50, 53, 54, 59, 32, 99, 61, 114, 101, 108, 97, 120,
//         101, 100, 47, 114, 101, 108, 97, 120, 101, 100, 59, 32, 100, 61, 105, 99, 108, 111, 117,
//         100, 46, 99, 111, 109, 59, 32, 115, 61, 49, 97, 49, 104, 97, 105, 59, 32, 116, 61, 49, 54,
//         57, 51, 48, 51, 56, 51, 51, 55, 59, 32, 98, 104, 61, 55, 120, 81, 77, 68, 117, 111, 86, 86,
//         85, 52, 109, 48, 87, 48, 87, 82, 86, 83, 114, 86, 88, 77, 101, 71, 83, 73, 65, 83, 115, 110,
//         117, 99, 75, 57, 100, 74, 115, 114, 99, 43, 118, 85, 61, 59, 32, 104, 61, 102, 114, 111,
//         109, 58, 67, 111, 110, 116, 101, 110, 116, 45, 84, 121, 112, 101, 58, 77, 105, 109, 101, 45,
//         86, 101, 114, 115, 105, 111, 110, 58, 83, 117, 98, 106, 101, 99, 116, 58, 77, 101, 115, 115,
//         97, 103, 101, 45, 73, 100, 58, 68, 97, 116, 101, 58, 116, 111, 59, 32, 98, 61, 239, 191,
//         189, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
//         0, 0, 0, 0, 0, 0, 0, 0,
//     ];
//     let match_start = 267;
//     let match_length = 92;
//     let curr_states = [
//         1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 27, 28, 29, 30, 19, 27,
//         28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 29, 30, 19, 27, 28, 28, 28, 28, 28, 28, 28, 28, 28,
//         28, 28, 28, 28, 28, 28, 29, 30, 19, 27, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 29, 30, 19,
//         27, 28, 28, 28, 28, 28, 28, 29, 30, 31, 32, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 0, 0, 0,
//         0, 0, 0, 0, 0,
//     ];
//     let next_states = [
//         2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 27, 28, 29, 30, 19, 27, 28,
//         28, 28, 28, 28, 28, 28, 28, 28, 28, 29, 30, 19, 27, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
//         28, 28, 28, 28, 28, 29, 30, 19, 27, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 29, 30, 19, 27,
//         28, 28, 28, 28, 28, 28, 29, 30, 31, 32, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 34, 0, 0, 0,
//         0, 0, 0, 0, 0,
//     ];

//     let capture_group_ids = [
//         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
//         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
//         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
//         0, 0, 0, 0, 0, 0, 0,
//     ];

//     let capture_group_starts = [
//         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
//         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
//         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
//         0, 0, 0, 0, 0, 0, 0,
//     ];
//     let capture_start_indices = [81];

//     let result = regex_match(
//         in_haystack,
//         match_start,
//         match_length,
//         curr_states,
//         next_states,
//         capture_group_ids,
//         capture_group_starts,
//         capture_start_indices,
//     );
// }
