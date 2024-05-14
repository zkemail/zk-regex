pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: a(b|c)+
template Plus2Regex(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		in[i+1] <== msg[i];
	}

	component eq[3][num_bytes];
	component and[3][num_bytes];
	component multi_or[2][num_bytes];
	signal states[num_bytes+1][3];
	signal states_tmp[num_bytes+1][3];
	signal from_zero_enabled[num_bytes+1];
	from_zero_enabled[num_bytes] <== 0;
	component state_changed[num_bytes];

	for (var i = 1; i < 3; i++) {
		states[0][i] <== 0;
	}

	for (var i = 0; i < num_bytes; i++) {
		state_changed[i] = MultiOR(2);
		states[i][0] <== 1;
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 97;
		and[0][i] = AND();
		and[0][i].a <== states[i][0];
		and[0][i].b <== eq[0][i].out;
		states_tmp[i+1][1] <== 0;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 98;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 99;
		and[1][i] = AND();
		and[1][i].a <== states[i][1];
		multi_or[0][i] = MultiOR(2);
		multi_or[0][i].in[0] <== eq[1][i].out;
		multi_or[0][i].in[1] <== eq[2][i].out;
		and[1][i].b <== multi_or[0][i].out;
		and[2][i] = AND();
		and[2][i].a <== states[i][2];
		and[2][i].b <== multi_or[0][i].out;
		multi_or[1][i] = MultiOR(2);
		multi_or[1][i].in[0] <== and[1][i].out;
		multi_or[1][i].in[1] <== and[2][i].out;
		states[i+1][2] <== multi_or[1][i].out;
		from_zero_enabled[i] <== MultiNOR(2)([states_tmp[i+1][1], states[i+1][2]]);
		states[i+1][1] <== MultiOR(2)([states_tmp[i+1][1], from_zero_enabled[i] * and[0][i].out]);
		state_changed[i].in[0] <== states[i+1][1];
		state_changed[i].in[1] <== states[i+1][2];
	}

	component final_state_result = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		final_state_result.in[i] <== states[i][2];
	}
	out <== final_state_result.out;
	signal is_consecutive[msg_bytes+1][3];
	is_consecutive[msg_bytes][2] <== 0;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][2] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
		is_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][2], is_consecutive[msg_bytes-1-i][1]]);
	}
	// substrings calculated: [{(1, 2), (2, 2)}]
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(1, 2), (2, 2)]
		is_substr0[i] <== MultiOR(2)([states[i+1][1] * states[i+2][2], states[i+1][2] * states[i+2][2]]);
		is_reveal0[i] <== is_substr0[i] * is_consecutive[i][2];
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
}