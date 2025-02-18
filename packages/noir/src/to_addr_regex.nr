// Test: https://github.com/zkemail/zk-regex/blob/main/packages/circom/tests/to_addr.test.js
// This combines 3 generated templates

// (\r\n|^)to: 
global TO_ALL_REGEX_MAX_PREFIX: u32 = 5;
// https://www.rfc-editor.org/errata/eid1690#:~:text=Section%203%20says%3A,total%20length%20of%20320%20characters.
pub global ADDR_REGEX_MAX_CAPTURE: u32 = 320;
// \r\n
global TO_ALL_REGEX_MAX_POSTFIX: u32 = 2;
pub global TO_ALL_REGEX_MAX_LEN: u32 = TO_ALL_REGEX_MAX_PREFIX + ADDR_REGEX_MAX_CAPTURE + TO_ALL_REGEX_MAX_POSTFIX;

use crate::{
    to_all_regex,
    email_addr_regex,
    common::extract_substring
};

fn regex_match<let N: u32>(input: [u8; N]) -> BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> {
    let (to_all_sequence, to_all_match) = to_all_regex::regex_match(input);
    assert(to_all_sequence.len() == 1, "Expected sequence found to to_all match");
    assert(to_all_match, "Expected match found to to_all match");
    let to_all_substring: BoundedVec<u8, TO_ALL_REGEX_MAX_LEN> = extract_substring(to_all_sequence.get_unchecked(0), input);
    let reversed_to_all = reverse_vec(to_all_substring);

    // At least 1 of the 2 should return true
    // This extracts the first occurence of an email address between brackets <> of the reversed string
    // (this ensure the last occurrence of an email is extracted)
    let (
        reversed_addr_sequence,
        reversed_addr_match
    ) = email_addr_regex::regex_match(reversed_to_all.storage());
    let (
        addr_sequence,
        _
    ) = email_addr_regex::regex_match(to_all_substring.storage());
    
    // If email between "<>" was obtained, return that
    // otherwise return any email that was encountered
    // otherwise this should fail since no valid email was found

    // check reversed
    let mut sequence_to_use = addr_sequence;
    let mut substring_to_use = to_all_substring;
    if (reversed_addr_match) {
        sequence_to_use = reversed_addr_sequence;
        substring_to_use = reversed_to_all;
    };
    let mut substr = extract_substring(
        sequence_to_use.get(0),
        substring_to_use.storage()
    );
    let unreversed = reverse_vec(substr);
    if reversed_addr_match {
        substr = unreversed;
    }
    substr
    
}

fn reverse_vec<let N: u32>(input: BoundedVec<u8, N>) -> BoundedVec<u8, N> {
    let mut reversed = unsafe { __reverse_vec(input) };
    for i in 0..N {
        let in_range = (i < reversed.len()) as Field;
        // if in range choose opposite index, otherwise choose same index to check 0's
        let index = (((input.len() as Field) - (i as Field * in_range) - 1) * in_range as Field + (i as Field * (1 - in_range))) as Field;
        let expected_byte = input.get_unchecked(index as u32) as Field * in_range as Field;
        let byte = reversed.get_unchecked(i) as Field;
        assert(byte == expected_byte, "Incorrect reverse");
    }
    reversed
}

unconstrained fn __reverse_vec<let N: u32>(input: BoundedVec<u8, N>) -> BoundedVec<u8, N> {
    let mut reversed: BoundedVec<u8, N> = BoundedVec::new();
    for i in 0..input.len() {
        reversed.push(input.get(input.len() - i - 1));
    }
    reversed
}

fn main(input: [u8; 1024]) {
    let res = regex_match(input);
}

/// TESTS ///

#[test]
fn test_valid_1() {
    // "to field from beginning case 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "to:adityabisht@gmail.com\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_2() {
    // "to field from beginning case 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "to:Aditya Bisht <adityabisht@gmail.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_3() {
    // "to field from beginning case 3 (email address as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "to:dummy@example.com<adityabisht@gmail.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_4() {
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    // "to field from beginning case 4 (non-English string is used as a name)"
    let input = "to: \"忠片返年\" <adityabisht@gmail.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_5() {
    // "to field after new line case 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "dummy\r\nto:adityabisht@gmail.com\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_6() {
    // "to field after new line case 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "dummy\r\nto:Sora Suegami <adityabisht@gmail.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_7() {
    // "to field after new line case 3 (email address as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "dummy\r\nto:dummy@example.com<adityabisht@gmail.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_8() {
    // "to field after new line case 4 (non-English string is used as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "dummy\r\nto: \"忠片返年\" <adityabisht@gmail.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_9() {
    // "to field containing @ in the name part"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("adityabisht@gmail.com@dummy.com".as_bytes());
    let input = "to:Aditya Bisht <adityabisht@gmail.com@dummy.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_10() {
    // FAILS
    // "to field starting from @"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("@gmail.com@dummy.com".as_bytes());
    let input = "to:Aditya Bisht <@gmail.com@dummy.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_11() {
    // "to field with double <> 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "to:\"Some name <victim@any-domain>\" <attacker@outlook.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_12() {
    // "to field with double <> 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "to:\"Some name <victim@any-domain>\" < attacker@outlook.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_13() {
    // "to field with double <> 3"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "to:\"Some name <victim@any-domain>\" <attacker@outlook.com >\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test]
fn test_valid_14() {
    // "to field with triple <>"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "to:\"Some name <victim1@any-domain<victim1@any-domain>>\" <attacker@outlook.com>\r\n".as_bytes();
    let matched_substr = regex_match(input);
    assert_eq(matched_substr, expected_match);
}

#[test(should_fail)]
fn test_invalid_1() {
    // "to field in the invalid field"
    let input = "subject:to:adityabisht@gmail.com\r\n".as_bytes();
    let _ = regex_match(input);
}

#[test(should_fail)]
fn test_invalid_2() {
    // "invalid to field with 255"
    // prepend 255 and 49 then append normal input
    let input = &[255, 49].append("to:adityabisht@gmail.com\r\n".as_bytes()).as_array();
    let _ = regex_match(input);
}
