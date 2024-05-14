pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: [A-Za-z0-9!#$%&'*+=?^_`{|}~.]+@[A-Za-z0-9.-]+
template EmailAddrRegex(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		in[i+1] <== msg[i];
	}

	component eq[13][num_bytes];
	component and[5][num_bytes];
	component multi_or[3][num_bytes];
	signal states[num_bytes+1][4];
	signal states_tmp[num_bytes+1][4];
	signal from_zero_enabled[num_bytes+1];
	from_zero_enabled[num_bytes] <== 0;
	component state_changed[num_bytes];

	for (var i = 1; i < 4; i++) {
		states[0][i] <== 0;
	}

	for (var i = 0; i < num_bytes; i++) {
		state_changed[i] = MultiOR(3);
		states[i][0] <== 1;
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 1;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 3;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 5;
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 8;
		eq[4][i] = IsEqual();
		eq[4][i].in[0] <== in[i];
		eq[4][i].in[1] <== 10;
		eq[5][i] = IsEqual();
		eq[5][i].in[0] <== in[i];
		eq[5][i].in[1] <== 12;
		eq[6][i] = IsEqual();
		eq[6][i].in[0] <== in[i];
		eq[6][i].in[1] <== 14;
		eq[7][i] = IsEqual();
		eq[7][i].in[0] <== in[i];
		eq[7][i].in[1] <== 16;
		eq[8][i] = IsEqual();
		eq[8][i].in[0] <== in[i];
		eq[8][i].in[1] <== 18;
		eq[9][i] = IsEqual();
		eq[9][i].in[0] <== in[i];
		eq[9][i].in[1] <== 19;
		eq[10][i] = IsEqual();
		eq[10][i].in[0] <== in[i];
		eq[10][i].in[1] <== 20;
		and[0][i] = AND();
		and[0][i].a <== states[i][0];
		multi_or[0][i] = MultiOR(11);
		multi_or[0][i].in[0] <== eq[0][i].out;
		multi_or[0][i].in[1] <== eq[1][i].out;
		multi_or[0][i].in[2] <== eq[2][i].out;
		multi_or[0][i].in[3] <== eq[3][i].out;
		multi_or[0][i].in[4] <== eq[4][i].out;
		multi_or[0][i].in[5] <== eq[5][i].out;
		multi_or[0][i].in[6] <== eq[6][i].out;
		multi_or[0][i].in[7] <== eq[7][i].out;
		multi_or[0][i].in[8] <== eq[8][i].out;
		multi_or[0][i].in[9] <== eq[9][i].out;
		multi_or[0][i].in[10] <== eq[10][i].out;
		and[0][i].b <== multi_or[0][i].out;
		and[1][i] = AND();
		and[1][i].a <== states[i][1];
		and[1][i].b <== multi_or[0][i].out;
		states_tmp[i+1][1] <== and[1][i].out;
		eq[11][i] = IsEqual();
		eq[11][i].in[0] <== in[i];
		eq[11][i].in[1] <== 15;
		and[2][i] = AND();
		and[2][i].a <== states[i][1];
		and[2][i].b <== eq[11][i].out;
		states[i+1][2] <== and[2][i].out;
		eq[12][i] = IsEqual();
		eq[12][i].in[0] <== in[i];
		eq[12][i].in[1] <== 7;
		and[3][i] = AND();
		and[3][i].a <== states[i][2];
		multi_or[1][i] = MultiOR(5);
		multi_or[1][i].in[0] <== eq[12][i].out;
		multi_or[1][i].in[1] <== eq[3][i].out;
		multi_or[1][i].in[2] <== eq[4][i].out;
		multi_or[1][i].in[3] <== eq[7][i].out;
		multi_or[1][i].in[4] <== eq[9][i].out;
		and[3][i].b <== multi_or[1][i].out;
		and[4][i] = AND();
		and[4][i].a <== states[i][3];
		and[4][i].b <== multi_or[1][i].out;
		multi_or[2][i] = MultiOR(2);
		multi_or[2][i].in[0] <== and[3][i].out;
		multi_or[2][i].in[1] <== and[4][i].out;
		states[i+1][3] <== multi_or[2][i].out;
		from_zero_enabled[i] <== MultiNOR(3)([states_tmp[i+1][1], states[i+1][2], states[i+1][3]]);
		states[i+1][1] <== MultiOR(2)([states_tmp[i+1][1], from_zero_enabled[i] * and[0][i].out]);
		state_changed[i].in[0] <== states[i+1][1];
		state_changed[i].in[1] <== states[i+1][2];
		state_changed[i].in[2] <== states[i+1][3];
	}

	component final_state_result = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		final_state_result.in[i] <== states[i][3];
	}
	out <== final_state_result.out;
	signal is_consecutive[msg_bytes+1][3];
	is_consecutive[msg_bytes][2] <== 0;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][3] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
		is_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][3], is_consecutive[msg_bytes-1-i][1]]);
	}
	// substrings calculated: [{(0, 1), (1, 1), (1, 2), (2, 3), (3, 3)}]
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(0, 1), (1, 1), (1, 2), (2, 3), (3, 3)]
		is_substr0[i] <== MultiOR(5)([states[i+1][0] * states[i+2][1], states[i+1][1] * states[i+2][1], states[i+1][1] * states[i+2][2], states[i+1][2] * states[i+2][3], states[i+1][3] * states[i+2][3]]);
		is_reveal0[i] <== is_substr0[i] * is_consecutive[i][2];
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
}