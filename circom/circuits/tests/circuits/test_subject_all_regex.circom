pragma circom 2.1.5;

include "../../common/subject_all_regex.circom";

// IMPORTANT: These parameters MUST match the maxHaystackBytes and maxMatchBytes
// used in the test file (subject_all.test.ts) when calling genCircuitInputs().
//
// Parameters: SubjectAllRegex(maxHaystackBytes, maxMatchBytes)
// - maxHaystackBytes: Maximum size of the input haystack (640)
// - maxMatchBytes: Maximum size of the match/capture groups (64)
//
// If you change these values, you MUST update the corresponding values in the test file,
// otherwise you'll get "Not enough values for input signal" errors at witness generation.
component main = SubjectAllRegex(640, 64);
