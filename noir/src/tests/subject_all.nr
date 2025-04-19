use crate::common::subject_all_regex::regex_match;

#[test]
fn test_regex_match() {
    //TODO UPDATE
    // inputs (use `./scripts/gen_inputs.sh subject_all`)
    let haystack = [
        13, 10, 115, 117, 98, 106, 101, 99, 116, 58, 32, 116, 104, 105, 115, 32, 115, 105, 32, 97,
        32, 98, 117, 106, 101, 99, 116, 13, 10, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0,
    ];
    let curr_states = [
        0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 18, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19,
        19, 19, 19, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];
    let next_states = [
        2, 3, 4, 5, 6, 7, 8, 9, 10, 18, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19,
        19, 19, 20, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];
    let traversal_path_length = 29;

    // call the regex_match function
    // regex_match(haystack, curr_states, next_states, traversal_path_length);
}
