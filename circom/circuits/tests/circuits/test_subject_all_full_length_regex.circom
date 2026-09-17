pragma circom 2.1.5;

include "../../common/subject_all_regex.circom";

// Smallest instantiation the capture width (64) allows, so that a 64-byte subject line fills the
// whole match window, i.e. matchLength == maxMatchBytes. Used by traversal_linkage.test.ts.
//
// Parameters: SubjectAllRegex(maxHaystackBytes, maxMatchBytes)
component main = SubjectAllRegex(128, 64);
