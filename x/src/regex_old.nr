global table: [Field; 2560] = comptime { make_lookup_table() };
pub fn regex_match<let N: u32>(input: [u8; N]) -> Vec<BoundedVec<Field, N>> {
    // regex: x[0-9]{2}-y{2,3}_z$
    let mut substrings: Vec<BoundedVec<Field, N>> = Vec::new();

    // "Previous" state
    let mut s: Field = 0;
    s = table[255];
    // "Next"/upcoming state
    let mut s_next: Field = 0;

    let mut consecutive_substr = 0;
    let mut current_substring = BoundedVec::new();

    for i in 0..input.len() {
        let temp = input[i] as Field;
        let mut reset = false;
        s_next = table[s * 256 + temp];
        if s_next == 0 {
          // Check if there is any transition that could be done from a "restart"
          s_next = table[temp];
          // whether the next state changes or not, we mark this as a reset.
          reset = true;
          s = 0;
        }

        // If a substring was in the making, but the state was reset
        // we disregard previous progress because apparently it is invalid
        if (reset & (consecutive_substr == 1)) {
            current_substring = BoundedVec::new();
            consecutive_substr = 0;
        }
        // Fill up substrings
         else if ((consecutive_substr == 1) & (s_next == 0)) {
            current_substring = BoundedVec::new();
            consecutive_substr = 0;
        } else if (consecutive_substr == 1) {
            // The substring is done so "save" it
            substrings.push(current_substring);
            // reset the substring holder for next use
            current_substring = BoundedVec::new();
            consecutive_substr = 0;
        }
        s = s_next;
    }
    assert((s == 9), f"no match: {s}");
    // Add pending substring that hasn't been added
    if consecutive_substr == 1 {
        substrings.push(current_substring);
    }
    substrings
}
        
comptime fn make_lookup_table() -> [Field; 2560] {
    let mut table = [0; 2560];
    table[0 * 256 + 120] = 1;
    table[1 * 256 + 48] = 2;
    table[1 * 256 + 49] = 2;
    table[1 * 256 + 50] = 2;
    table[1 * 256 + 51] = 2;
    table[1 * 256 + 52] = 2;
    table[1 * 256 + 53] = 2;
    table[1 * 256 + 54] = 2;
    table[1 * 256 + 55] = 2;
    table[1 * 256 + 56] = 2;
    table[1 * 256 + 57] = 2;
    table[2 * 256 + 48] = 3;
    table[2 * 256 + 49] = 3;
    table[2 * 256 + 50] = 3;
    table[2 * 256 + 51] = 3;
    table[2 * 256 + 52] = 3;
    table[2 * 256 + 53] = 3;
    table[2 * 256 + 54] = 3;
    table[2 * 256 + 55] = 3;
    table[2 * 256 + 56] = 3;
    table[2 * 256 + 57] = 3;
    table[3 * 256 + 45] = 4;
    table[4 * 256 + 121] = 5;
    table[5 * 256 + 121] = 6;
    table[6 * 256 + 121] = 7;
    table[6 * 256 + 95] = 8;
    table[7 * 256 + 95] = 8;
    table[8 * 256 + 122] = 9;


    table
}