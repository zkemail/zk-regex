use regex::to_addr_regex::regex_match;

fn main(input: [u8; 1024]) -> pub BoundedVec<u8, 320>{
    regex_match(input)
}