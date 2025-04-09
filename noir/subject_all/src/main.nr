mod regex;
mod common;

global MAX_HAYSTACK_LEN: u32 = 50;

fn main(
    haystack: [u8; MAX_HAYSTACK_LEN],
    curr_states: [Field; MAX_HAYSTACK_LEN],
    next_states: [Field; MAX_HAYSTACK_LEN],
    traversal_path_length: u32,
) {
    regex::regex_match(
        haystack,
        curr_states,
        next_states,
        traversal_path_length,
    )
}


#[test]
fn test_regex_match() {
    let haystack = [13, 10, 115, 117, 98, 106, 101, 99, 116, 58, 32, 116, 104, 105, 115, 32, 115, 105, 32, 97, 32, 98, 117, 106, 101, 99, 116, 13, 10, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let curr_states = [0, 0, 0, 8, 9, 10, 11, 12, 13, 14, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let next_states = [0, 0, 8, 9, 10, 11, 12, 13, 14, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 25, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let traversal_path_length = 29;

    main(haystack, curr_states, next_states, traversal_path_length);
}    
    