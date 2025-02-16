/**
 * Defines common regex structures and functions to be used in generated code
 *
 * @returns the common regex file definition
 */
pub fn get_common_regex_def() -> String {
    format!(
        r#"
    {SEQUENCE_DEF}

    {SUBSTRING_MATCH_DEF}

    {EXTRACT_SUBSTRING_DEF}

    {MASK_MATCH_DEF}
    "#
    )
}

const SEQUENCE_DEF: &str = r#"
// points to a seque
pub struct Sequence {
    index: u32,
    length: u32,
    end: u32
}

impl Sequence {
    pub fn new(index: u32, length: u32) -> Self {
        Self { index, length, end: index + length }
    }

    pub fn default() -> Self {
        Self { index: 0, length: 0, end: 0 }
    }

    pub fn initialized(self) -> bool {
        self.length > 0
    }

    pub fn index(self) -> u32 {
        self.index
    }

    pub fn length(self) -> u32 {
        self.length
    }

    pub fn end(self) -> u32 {
        self.end
    }

    pub fn in_range(self, index: u32) -> bool {
        // if index + length == 0, index < self.end implicitly returns false if uninitialized
        index >= self.index & index < self.end
    }
}
"#;

const SUBSTRING_MATCH_DEF: &str = r#"
pub struct SubstringMatch<let NUM_SUBSTRINGS: u32> {
    substrings: BoundedVec<Sequence, NUM_SUBSTRINGS>,
}
"#;

const EXTRACT_SUBSTRING_DEF: &str = r#"
/**
 * Extracts all substrings from a pattern match
 * @dev not super optimal - all substrings will be assumed to be of the length of longest substring.
 *      often this will be the size of the input. Use at discretion.
 * 
 * @param input - the input array to extract from
 * @param sequences - the sequences to extract from the input
 * @returns the extracted substrings
 */
pub fn extract_all_substrings<
    let INPUT_LENGTH: u32,
    let NUM_SUBSTRINGS: u32,
    let MAX_SUBSTRING_LENGTH: u32
>(
    input: [u8; INPUT_LENGTH],
    sequences: BoundedVec<Sequence, NUM_SUBSTRINGS>,
) -> BoundedVec<BoundedVec<u8, MAX_SUBSTRING_LENGTH>, NUM_SUBSTRINGS> {{
    let mut substrings: BoundedVec<BoundedVec<u8, MAX_SUBSTRING_LENGTH>, NUM_SUBSTRINGS> = BoundedVec::new();
    for i in 0..NUM_SUBSTRINGS {{
        let substring = sequences.get_unchecked(i);
        let mut extracted_substring = extract_substring(substring, input);
        let mut len = substrings.len() + 1;
        if i >= sequences.len() {{
            extracted_substring = BoundedVec::new();
            len = substrings.len();
        }}
        substrings.len = len;
        substrings.storage[i] = extracted_substring;
    }}
    substrings
}}

/**
 * Optimized algorithm for extracting a subsequence from an input array
 * 
 * @param substring_sequence - the sequence to extract from the input
 * @param input - the input array to extract from
 * @returns the extracted subsequence
 */
pub fn extract_substring<let INPUT_LENGTH: u32, let MAX_SUBSTRING_LENGTH: u32>(
    substring_sequence: Sequence,
    input: [u8; INPUT_LENGTH],
) -> BoundedVec<u8, MAX_SUBSTRING_LENGTH> {
    let mut substring: BoundedVec<u8, MAX_SUBSTRING_LENGTH> = unsafe { __extract_substring(substring_sequence, input) };
    assert(substring_sequence.length == substring.len(), "length mismatch");
    for i in 0..MAX_SUBSTRING_LENGTH {
        // hack for index to never exceed array bounds
        // must be constrained to be true when matching is required to prevent 0's passing when shouldn't
        // @dev while this adds constraints in worse case it can be more efficient if MAX_SUBSTRING_LENGTH < INPUT_LENGTH
        let input_range_check = substring_sequence.index + i < INPUT_LENGTH;
        let index = (substring_sequence.index + i) as Field * input_range_check as Field;

        // range where input should match substring
        let sequence_range_check = i >= substring_sequence.length;
        
        // constrain array construction if in range
        let expected_byte = input[index];
        let byte = substring.get_unchecked(i);
        let matched = (expected_byte as Field == byte as Field);
        assert(matched | sequence_range_check, "incorrect substring construction");
    }
    substring
}

/**
 * Unconstrained helper to build the extracted substring
 * @dev must be checked by extract_substring to constrain construction of substring
 * 
 * @param substring_sequence - the sequence to extract from the input
 * @param input - the input array to extract from
 * @returns the extracted subsequence
 */
unconstrained fn __extract_substring<let INPUT_LENGTH: u32, let MAX_SUBSTRING_LENGTH: u32>(
    substring_sequence: Sequence,
    input: [u8; INPUT_LENGTH],
) -> BoundedVec<u8, MAX_SUBSTRING_LENGTH> {
    let mut substring: BoundedVec<u8, MAX_SUBSTRING_LENGTH> = BoundedVec::new();
    for i in 0..substring_sequence.length {
        let byte = input[substring_sequence.index + i];
        substring.push(byte);
    }
    substring
}
    "#;

const MASK_MATCH_DEF: &str = r#"
// pub fn mask_input<let INPUT_LENGTH: u32, let MAX_SUBSTRING_LENGTH: u32>(
//     substring_sequences: BoundedVec<Sequence, MAX_SUBSTRING_LENGTH>,
//     input: [u8; INPUT_LENGTH],
// ) -> [u8; INPUT_LENGTH] {
//     let masked: [u8; INPUT_LENGTH] = unsafe { __mask_input(substring_sequences, input) };
//     for i in 0..INPUT_LENGTH {
//         let any_in_range = substring_sequences
//             .storage()
//             .any(|sequence| sequence.in_range(i));
//         let expected_byte = input[i] as Field * any_in_range as Field;
//         assert(masked[i] as Field == expected_byte, "Incorrect masking");
//     }
//     masked
// }

unconstrained fn __mask_input<let INPUT_LENGTH: u32, let MAX_SUBSTRING_LENGTH: u32>(
    substring_sequences: BoundedVec<Sequence, MAX_SUBSTRING_LENGTH>,
    input: [u8; INPUT_LENGTH],
) -> [u8; INPUT_LENGTH] {
    let mut masked_input: [u8; INPUT_LENGTH] = [0; INPUT_LENGTH];
    for i in 0..substring_sequences.len() {
        let sequence = substring_sequences.get_unchecked(i);
        for j in sequence.index..sequence.end() {
            masked_input[j] = input[j];
        }
    }
    masked_input
}
"#;
