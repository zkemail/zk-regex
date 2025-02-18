
use crate::regex_common::Sequence;


global table: [Field; 768] = comptime { make_lookup_table() };

comptime fn make_lookup_table() -> [Field; 768] {
    let mut table = [0; 768];
        table[0 * 256 + 97] = 1;
    table[1 * 256 + 98] = 2;
    table[1 * 256 + 99] = 2;

    table
}


pub fn regex_match<let N: u32>(input: [u8; N]) -> BoundedVec<Sequence, 1> {
    let substrings = unsafe { __regex_match(input) };
    
    // "Previous" state
    let mut s: Field = 0;
    s = table[255];
    // "Next"/upcoming state
    let mut s_next: Field = 0;
    let mut start_range = 0;
    let mut end_range = 0;

    // check the match
    for i in 0..N {
        // state transition
        let temp = input[i] as Field;
        s_next = table[s * 256 + temp];
        let potential_s_next = table[temp];
        if s_next == 0 {
            s = 0;
            s_next = potential_s_next;
        }
        std::as_witness(s_next);

        // range conditions for substring matches
        if ((start_range == 0) & (end_range == 0)) {
            start_range = i as Field;
        }
        if (((s == 2) & (s_next == 2)) & (end_range == 0)) {
            end_range = i as Field + 1;
        }
        

        let range_0 = substrings.get_unchecked(0).in_range(i);
        let case_0 = [
            (s_next == 1) & ((s == 0)),
        	(s_next == 2) & ((s == 1))
        ].any(|case| case == true) | !range_0;



        let substring_range_check = [case_0]
            .all(|case| case == true);
    
        assert(substring_range_check, "substr array ranges wrong");
                
    
        s = s_next;
    }
    // check final state
    
    assert((s == 2), "Match not found");
            
    // constrain extracted substrings to be in match range
    //let full_match = Sequence::new(start_range as u32, end_range as u32 - start_range as u32);
    //let full_match_end = full_match.end();
    // for i in 0..1 {
    //     let substring = substrings.get_unchecked(i);
    //     let is_not_valid = i >= substrings.len();
    //     let index_check = substring.index >= full_match.index;
    //     let length_check = substring.end() <= full_match_end;
    //     let check = (index_check) | is_not_valid;
    //     assert(check, f"Substring {i} range is out of bounds of the full match found");
    // }
    substrings
}
    

pub unconstrained fn __regex_match<let N: u32>(input: [u8; N]) ->  BoundedVec<Sequence, 1> {
    // regex: a[bc]$
    let mut substrings: BoundedVec<Sequence, 1> = BoundedVec::new();
    let mut current_substring = Sequence::default();
    let mut full_match = Sequence::default();

    // "Previous" state
    let mut s: Field = 0;
    s = table[255];
    // "Next"/upcoming state
    let mut s_next: Field = 0;

    let mut consecutive_substr = 0;
    let mut complete = false;

    for i in 0..input.len() {
        let temp = input[i] as Field;
        let mut reset = false;
        s_next = table[s * 256 + temp];
        let potential_s_next = table[temp];
        if s_next == 0 {
            reset = true;
            s = 0;
            s_next = potential_s_next;
        }
        // If a substring was in the making, but the state was reset
        // we disregard previous progress because apparently it is invalid
        if (reset & (consecutive_substr == 1)) {
            current_substring = Sequence::default();
            consecutive_substr = 0;
        }
        // Fill up substrings


        if ((s == 0) & (s_next == 1) | (s == 1) & (s_next == 2)) {
    
            if (consecutive_substr == 0) {
                current_substring.index = i;
            };
            current_substring.length += 1;
            consecutive_substr = 1; 
        } else if ((consecutive_substr == 1) & (s_next == 0)) {
            current_substring = Sequence::default();
            full_match = Sequence::default();
            substrings = BoundedVec::new();
            consecutive_substr = 0;
        } else if (s == 2) & (s_next == 2) {
            full_match.length = i - full_match.index + 1;
            complete = true;
        } else if (consecutive_substr == 1) {
            // The substring is done so "save" it
            substrings.push(current_substring);
            // reset the substring holder for next use
            current_substring = Sequence::default();
            consecutive_substr = 0;
        }
        s = s_next;
        if complete == true {
            break;
        }
    }
    assert((s == 2), f"no match: {s}");
    // Add pending substring that hasn't been added
    if consecutive_substr == 1 {
        substrings.push(current_substring);
        full_match.length = input.len() - full_match.index;
    }

    

    substrings
}
    
            
        
            