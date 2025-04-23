use crate::common::simple_regex::regex_match;

#[test]
fn test_regex_match() {
    // inputs (use `./scripts/gen_inputs.sh subject_all`)

    let haystack = [97, 97, 97, 97, 97, 97, 97, 98, 0, 0];
    let curr_states = [0, 1, 1, 1, 1, 1, 1, 1, 0, 0];
    let next_states = [1, 1, 1, 1, 1, 1, 1, 4, 0, 0];
    let traversal_path_length = 8;

    // call the regex_match function
    // regex_match(haystack, curr_states, next_states, traversal_path_length);
}
