/// BYTE SEQUENCE POINTER ///

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
        // if indexend == 0, index < self.end implicitly returns false if uninitialized
        index >= self.index & index < self.end
    }
}

/// SUBSTRING CAPTURE EXTRACTION ///

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

/// SUBSTRING CAPTURE INPUT MASKING ///

/**
 * Masks input to only reveal public captures defined in the regex
 *
 * @param substring_sequences - the sequences to mask from the input
 * @param input - the input array to mask
 * @returns the input masked to only reveal public captures defined in the regex
 */
pub fn mask_input<let INPUT_LENGTH: u32, let MAX_SUBSTRING_LENGTH: u32>(
    substring_sequences: BoundedVec<Sequence, MAX_SUBSTRING_LENGTH>,
    input: [u8; INPUT_LENGTH],
) -> [u8; INPUT_LENGTH] {

    let masked: [u8; INPUT_LENGTH] = unsafe { __mask_input(substring_sequences, input) };
    for i in 0..INPUT_LENGTH {
        let any_in_range = substring_sequences
            .storage()
            .any(| sequence: Sequence | sequence.in_range(i));
        let expected_byte = input[i] as Field * any_in_range as Field;
        assert(masked[i] as Field == expected_byte, "Incorrect masking");
    }
    masked
}

/**
 * Unconstrained helper to mask input
 * @dev SHOULD NOT BE CALLED BY ANYTHING EXCEPT `mask_input`
 * 
 * @param substring_sequences - the sequences to mask from the input
 * @param input - the input array to mask
 * @returns the input masked to only reveal public captures defined in the regex
 */
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

/// VECTOR REVERSAL ///

pub fn reverse_vec<let N: u32>(input: BoundedVec<u8, N>) -> BoundedVec<u8, N> {
    let mut reversed = unsafe { __reverse_vec(input) };
    for i in 0..N {
        let in_range = (i < reversed.len()) as Field;
        // if in range choose opposite index, otherwise choose same index to check 0's
        // yeah I know this is ugly show me a more efficient version and I'll use it
        let index = (((input.len() as Field) - (i as Field * in_range) - 1) * in_range as Field + (i as Field * (1 - in_range))) as Field;
        let expected_byte = input.get_unchecked(index as u32) as Field * in_range as Field;
        let byte = reversed.get_unchecked(i) as Field;
        assert(byte == expected_byte, "Incorrect reverse");
    }
    reversed
}

unconstrained fn __reverse_vec<let N: u32>(input: BoundedVec<u8, N>) -> BoundedVec<u8, N> {
    let mut reversed: BoundedVec<u8, N> = BoundedVec::new();
    for i in 0..input.len() {
        reversed.push(input.get(input.len() - i - 1));
    }
    reversed
}