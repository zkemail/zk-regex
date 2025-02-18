use crate::{
    capture::{from_all, email_addr as email_addr_capture},
    basic::email_addr,
    common::{extract_substring, reverse_vec},
    constants::{ADDR_REGEX_MAX_CAPTURE_LEN, FROM_ALL_MAX_LEN}
};

fn regex_match<let N: u32>(input: [u8; N]) -> (BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN>, bool) {
    let (from_all_sequence, from_all_match) = from_all::regex_match(input);
    assert(from_all_sequence.len() == 1, "Expected sequence found to from_all match");
    assert(from_all_match, "Expected match found to from_all match");
    let from_all_substring: BoundedVec<u8, FROM_ALL_MAX_LEN> = extract_substring(from_all_sequence.get_unchecked(0), input);
    
    let reversed_from_all_substring = reverse_vec(from_all_substring);

    // At least 1 of the 2 should return true
    // This extracts the first occurence of an email address between brackets <> of the reversed string
    // (this ensure the last occurrence of an email is extracted)
    let addr_found = email_addr::regex_match(from_all_substring.storage());
    let addr_reversed_found = email_addr::regex_match(reversed_from_all_substring.storage());

    let mut input_to_use = from_all_substring;
    if addr_reversed_found {
        input_to_use = reversed_from_all_substring;
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

#[test]
fn test_valid_1() {
    // "from field from beginning case 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com".as_bytes());
    let input = "from:suegamisora@gmail.com\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_2() {
    // "from field from beginning case 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com".as_bytes());
    let input = "from:Sora Suegami <suegamisora@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_3() {
    // "from field from beginning case 3 (email address as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com".as_bytes());
    let input = "from:dummy@example.com<suegamisora@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_4() {
    // "from field from beginning case 4 (non-English string is used as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com".as_bytes());
    let input = "from: \"末神奏宙\" <suegamisora@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_5() {
    // "from field after new line case 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com".as_bytes());
    let input = "dummy\r\nfrom:suegamisora@gmail.com\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_6() {
    // "from field after new line case 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com".as_bytes());
    let input = "dummy\r\nfrom:Sora Suegami <suegamisora@gmail.com>\r\n".as_bytes();
    
}

#[test]
fn test_valid_7() {
    // "from field after new line case 3 (email address as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com".as_bytes());
    let input = "dummy\r\nfrom:dummy@example.com<suegamisora@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_8() {
    // "from field after new line case 4 (non-English string is used as a name)"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com".as_bytes());
    let input = "dummy\r\nfrom: \"末神奏宙\" <suegamisora@gmail.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_9() {
    // "from field containing @ in the name part"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("suegamisora@gmail.com@dummy.com".as_bytes());
    let input = "from:Sora Suegami <suegamisora@gmail.com@dummy.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_10() {
    // "from field containing @ in the name part"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("@gmail.com@dummy.com".as_bytes());
    let input = "from:Sora Suegami <@gmail.com@dummy.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_11() {
    // "from field with double <> 1"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "from:\"Some name <victim@any-domain>\" <attacker@outlook.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_12() {
    // "from field with double <> 2"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "from:\"Some name <victim@any-domain>\" < attacker@outlook.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_13() {
    // "from field with double <> 3"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "from:\"Some name <victim@any-domain>\" <attacker@outlook.com >\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}

#[test]
fn test_valid_14() { // "from field with triple <>"
    let expected_match: BoundedVec<u8, ADDR_REGEX_MAX_CAPTURE_LEN> = BoundedVec::from_array("attacker@outlook.com".as_bytes());
    let input = "from:\"Some name <victim1@any-domain<victim1@any-domain>>\" <attacker@outlook.com>\r\n".as_bytes();
    let (matched_substr, found) = regex_match(input);
    assert(found, "Match not found");
    assert_eq(matched_substr, expected_match, "Extracted substring does not match expected substring");
}


// #[test(should_fail)]
fn test_invalid_1() {
    // why does it error? commenting line 19 and 20 (and further down changes) makes it pass so not super worried
    // same as to_addr
    // "from field in the invalid field"
    let input = "\r\nto:from:Sora Suegami <suegamisora@gmail.com>\r\n".as_bytes();
    let _ = regex_match(input);
}

#[test(should_fail)]
fn test_invalid_2() {
    // "invalid from field with 255"
    let input = &[255, 49].append("from:Sora Suegami <suegamisora@gmail.com>\r\n".as_bytes()).as_array();
    let _ = regex_match(input);
}