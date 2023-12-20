pragma circom 2.1.5;

include "./simple_regex_decomposed.circom";
// email was meant for @[a-zA-Z0-9_]+\.
component main = SimpleRegexDecomposed(64);