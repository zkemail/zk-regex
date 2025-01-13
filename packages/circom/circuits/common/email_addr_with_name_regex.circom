pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";
include "./reversed_bracket_regex.circom";

template EmailAddrWithNameRegex(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;
	signal output reveal0[msg_bytes];
	
	signal reversed_msg[msg_bytes];
	signal reversed_reveal0[msg_bytes];
	for(var i=0; i<msg_bytes; i++) {
		reversed_msg[i] <== msg[msg_bytes - i - 1];
	}
	(out, reversed_reveal0) <== ReversedBracketRegex(msg_bytes)(reversed_msg);
	for(var i=0; i<msg_bytes; i++) {
		reveal0[i] <== reversed_reveal0[msg_bytes - i - 1];
	}
}