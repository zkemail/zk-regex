pragma circom 2.1.5;

include "./international_chars_decomposed.circom";
// email was meant for @[a-zA-Z0-9_]+\.
component main = InternationalCharsDecomposed(128);