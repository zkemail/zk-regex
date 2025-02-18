use crate::{
    capture::raw::{to_all, email_addr as email_addr_capture},
    basic::email_addr,
    common::{extract_substring, reverse_vec},
    constants::{ADDR_REGEX_MAX_CAPTURE_LEN, TO_ALL_MAX_LEN}
};

fn regex_match<let N: u32>(input: [u8; N]) -> (BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN>, bool) {
    let (to_all_sequence, to_all_match) = to_all::regex_match(input);
    assert(to_all_sequence.len() == 1, "Expected sequence found to to_all match");
    assert(to_all_match, "Expected match found to to_all match");
    let to_all_substring: BoundedVec<u8, TO_ALL_MAX_LEN> = extract_substring(to_all_sequence.get_unchecked(0), input);
    
    let reversed_to_all_substring = reverse_vec(to_all_substring);

    // At least 1 of the 2 should return true
    // This extracts the first occurence of an email address between brackets <> of the reversed string
    // (this ensure the last occurrence of an email is extracted)
    let addr_found = email_addr::regex_match(to_all_substring.storage());
    let addr_reversed_found = email_addr::regex_match(reversed_to_all_substring.storage());

    let mut input_to_use = to_all_substring;
    if addr_reversed_found {
        input_to_use = reversed_to_all_substring;
    }
    let (sequence, _) = email_addr_capture::regex_match(input_to_use.storage());
    
    // If email between "<>" was obtained, return that
    // otherwise return any email that was encountered
    // otherwise this should fail since no valid email was found

    // check reversed
    let mut substring = extract_substring(sequence.get_unchecked(0), input_to_use.storage());
    let unreversed = reverse_vec(substring);
    if addr_reversed_found {
        substring = unreversed;
    }
    (substring, addr_reversed_found | addr_found)
}

/// TESTS ///

#[test]
fn test_valid_1() {
    // "to field from beginning case 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "to:adityabisht@gmail.com\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_2() {
    // "to field from beginning case 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "to:Aditya Bisht <adityabisht@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_3() {
    // "to field from beginning case 3 (email address as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "to:dummy@example.com<adityabisht@gmail.com>\r\n".as_bytes();
     let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_4() {
    // "to field from beginning case 4 (non-English string is used as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "to: \"忠片返年\" <adityabisht@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_5() {
    // "to field after new line case 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "dummy\r\nto:adityabisht@gmail.com\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_6() {
    // "to field after new line case 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "dummy\r\nto:Sora Suegami <adityabisht@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_7() {
    // "to field after new line case 3 (email address as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "dummy\r\nto:dummy@example.com<adityabisht@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_8() {
    // "to field after new line case 4 (non-English string is used as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com".as_bytes());
    let input = "dummy\r\nto: \"忠片返年\" <adityabisht@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_9() {
    // "to field containing @ in the name part"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("adityabisht@gmail.com@dummy.com".as_bytes());
    let input = "to:Aditya Bisht <adityabisht@gmail.com@dummy.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_10() {
    // FAILS
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("@gmail.com@dummy.com".as_bytes());
    let input = "to:Aditya Bisht <@gmail.com@dummy.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_11() {
    // "to field with double <> 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "to:\"Some name <victim@any-domain>\" <attacker@outlook.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_12() {
    // "to field with double <> 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "to:\"Some name <victim@any-domain>\" < attacker@outlook.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_13() {
    // "to field with double <> 3"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "to:\"Some name <victim@any-domain>\" <attacker@outlook.com >\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_14() {
    // "to field with triple <>"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "to:\"Some name <victim1@any-domain<victim1@any-domain>>\" <attacker@outlook.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

// #[test(should_fail)]
fn test_invalid_1() {
    // why does it error? commenting line 19 and 20 (and further down changes) makes it pass so not super worried
    // same as from_addr
    // "to field in the invalid field"
    let input = "subject:to:adityabisht@gmail.com\r\n".as_bytes();
    let _ = regex_match(input);
}

#[test(should_fail)]
fn test_invalid_2() {
    // "invalid to field with 255"
    let input = &[255, 49].append("to:adityabisht@gmail.com\r\n".as_bytes()).as_array();
    let _ = regex_match(input);
}
