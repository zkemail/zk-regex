use regex::capture::to_addr;

fn main(input: [u8; 1024]) -> pub BoundedVec<u8, 320>{
    let (substring, found) = to_addr::regex_match(input);
    assert(found, "Match not found");
    substring
}