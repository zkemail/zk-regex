pragma circom 2.1.5;
include "./simple_regex.circom";
// 1=(a|b) (2=(b|c)+ )+d
component main = SimpleRegex(64);