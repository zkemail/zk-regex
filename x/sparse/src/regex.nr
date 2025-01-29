global table: sparse_array::SparseArray<28, Field> = sparse_array::SparseArray {
    keys: [0x00000000, 0x00000078, 0x00000130, 0x00000131, 0x00000132, 0x00000133, 0x00000134, 0x00000135, 0x00000136, 0x00000137, 0x00000138, 0x00000139, 0x00000230, 0x00000231, 0x00000232, 0x00000233, 0x00000234, 0x00000235, 0x00000236, 0x00000237, 0x00000238, 0x00000239, 0x0000032d, 0x00000479, 0x00000579, 0x0000065f, 0x00000679, 0x0000075f, 0x0000087a, 0x000009ff],
    values: [0x00000000, 0x00000000, 0x00000001, 0x00000002, 0x00000002, 0x00000002, 0x00000002, 0x00000002, 0x00000002, 0x00000002, 0x00000002, 0x00000002, 0x00000002, 0x00000003, 0x00000003, 0x00000003, 0x00000003, 0x00000003, 0x00000003, 0x00000003, 0x00000003, 0x00000003, 0x00000003, 0x00000004, 0x00000005, 0x00000006, 0x00000008, 0x00000007, 0x00000008, 0x00000009, 0x00000000],
    maximum: 0x000009ff
};

            
pub fn regex_match<let N: u32>(input: [u8; N]) -> Vec<BoundedVec<Field, N>> {
    // regex: x[0-9]{2}-y{2,3}_z$
    let mut substrings: Vec<BoundedVec<Field, N>> = Vec::new();

    // "Previous" state
    let mut s: Field = 0;
    s = table.get(255);
    // "Next"/upcoming state
    let mut s_next: Field = 0;

    let mut consecutive_substr = 0;
    let mut current_substring = BoundedVec::new();

    for i in 0..input.len() {
        let temp = input[i] as Field;
        let mut reset = false;
        let mut s_next_idx = s * 256 + temp;
        if s_next == 0 {
          // Check if there is any transition that could be done from a "restart"
          s_next_idx = temp;
          // whether the next state changes or not, we mark this as a reset.
          reset = true;
          s = 0;
        }
        s_next = table.get(s_next_idx);
        

        // If a substring was in the making, but the state was reset
        // we disregard previous progress because apparently it is invalid
        if (reset & (consecutive_substr == 1)) {
            current_substring = BoundedVec::new();
            consecutive_substr = 0;
        }
        // Fill up substrings
        if ((s == 6) & (s_next == 8) | (s == 7) & (s_next == 8) | (s == 8) & (s_next == 9)) {
            if (consecutive_substr == 0) {
              current_substring.push(temp);
              consecutive_substr = 1;
            } else if (consecutive_substr == 1) {
              current_substring.push(temp);
            }   
        } else if ((consecutive_substr == 1) & (s_next == 0)) {
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