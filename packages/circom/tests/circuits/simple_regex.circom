pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: 1=(a|b) (2=(b|c)+ )+d
template SimpleRegex(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		in[i+1] <== msg[i];
	}

	component eq[8][num_bytes];
	component and[11][num_bytes];
	component multi_or[4][num_bytes];
	signal states[num_bytes+1][10];
	signal states_tmp[num_bytes+1][10];
	signal from_zero_enabled[num_bytes+1];
	from_zero_enabled[num_bytes] <== 0;
	component state_changed[num_bytes];

	for (var i = 1; i < 10; i++) {
		states[0][i] <== 0;
	}

	for (var i = 0; i < num_bytes; i++) {
		state_changed[i] = MultiOR(9);
		states[i][0] <== 1;
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 49;
		and[0][i] = AND();
		and[0][i].a <== states[i][0];
		and[0][i].b <== eq[0][i].out;
		states_tmp[i+1][1] <== 0;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 61;
		and[1][i] = AND();
		and[1][i].a <== states[i][1];
		and[1][i].b <== eq[1][i].out;
		states[i+1][2] <== and[1][i].out;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 97;
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 98;
		and[2][i] = AND();
		and[2][i].a <== states[i][2];
		multi_or[0][i] = MultiOR(2);
		multi_or[0][i].in[0] <== eq[2][i].out;
		multi_or[0][i].in[1] <== eq[3][i].out;
		and[2][i].b <== multi_or[0][i].out;
		states[i+1][3] <== and[2][i].out;
		eq[4][i] = IsEqual();
		eq[4][i].in[0] <== in[i];
		eq[4][i].in[1] <== 32;
		and[3][i] = AND();
		and[3][i].a <== states[i][3];
		and[3][i].b <== eq[4][i].out;
		states[i+1][4] <== and[3][i].out;
		eq[5][i] = IsEqual();
		eq[5][i].in[0] <== in[i];
		eq[5][i].in[1] <== 50;
		and[4][i] = AND();
		and[4][i].a <== states[i][4];
		and[4][i].b <== eq[5][i].out;
		and[5][i] = AND();
		and[5][i].a <== states[i][8];
		and[5][i].b <== eq[5][i].out;
		multi_or[1][i] = MultiOR(2);
		multi_or[1][i].in[0] <== and[4][i].out;
		multi_or[1][i].in[1] <== and[5][i].out;
		states[i+1][5] <== multi_or[1][i].out;
		and[6][i] = AND();
		and[6][i].a <== states[i][5];
		and[6][i].b <== eq[1][i].out;
		states[i+1][6] <== and[6][i].out;
		eq[6][i] = IsEqual();
		eq[6][i].in[0] <== in[i];
		eq[6][i].in[1] <== 99;
		and[7][i] = AND();
		and[7][i].a <== states[i][6];
		multi_or[2][i] = MultiOR(2);
		multi_or[2][i].in[0] <== eq[3][i].out;
		multi_or[2][i].in[1] <== eq[6][i].out;
		and[7][i].b <== multi_or[2][i].out;
		and[8][i] = AND();
		and[8][i].a <== states[i][7];
		and[8][i].b <== multi_or[2][i].out;
		multi_or[3][i] = MultiOR(2);
		multi_or[3][i].in[0] <== and[7][i].out;
		multi_or[3][i].in[1] <== and[8][i].out;
		states[i+1][7] <== multi_or[3][i].out;
		and[9][i] = AND();
		and[9][i].a <== states[i][7];
		and[9][i].b <== eq[4][i].out;
		states[i+1][8] <== and[9][i].out;
		eq[7][i] = IsEqual();
		eq[7][i].in[0] <== in[i];
		eq[7][i].in[1] <== 100;
		and[10][i] = AND();
		and[10][i].a <== states[i][8];
		and[10][i].b <== eq[7][i].out;
		states[i+1][9] <== and[10][i].out;
		from_zero_enabled[i] <== MultiNOR(9)([states_tmp[i+1][1], states[i+1][2], states[i+1][3], states[i+1][4], states[i+1][5], states[i+1][6], states[i+1][7], states[i+1][8], states[i+1][9]]);
		states[i+1][1] <== MultiOR(2)([states_tmp[i+1][1], from_zero_enabled[i] * and[0][i].out]);
		state_changed[i].in[0] <== states[i+1][1];
		state_changed[i].in[1] <== states[i+1][2];
		state_changed[i].in[2] <== states[i+1][3];
		state_changed[i].in[3] <== states[i+1][4];
		state_changed[i].in[4] <== states[i+1][5];
		state_changed[i].in[5] <== states[i+1][6];
		state_changed[i].in[6] <== states[i+1][7];
		state_changed[i].in[7] <== states[i+1][8];
		state_changed[i].in[8] <== states[i+1][9];
	}

	component is_accepted = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		is_accepted.in[i] <== states[i][9];
	}
	out <== is_accepted.out;
	signal is_consecutive[msg_bytes+1][3];
	is_consecutive[msg_bytes][2] <== 0;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][9] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
		is_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][9], is_consecutive[msg_bytes-1-i][1]]);
	}
	// substrings calculated: [{(2, 3)}, {(6, 7), (7, 7)}, {(8, 9)}]
	signal prev_states0[1][msg_bytes];
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(2, 3)]
		prev_states0[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][2];
		is_substr0[i] <== MultiOR(1)([prev_states0[0][i] * states[i+2][3]]);
		is_reveal0[i] <== MultiAND(3)([out, is_substr0[i], is_consecutive[i][2]]);
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
	signal prev_states1[2][msg_bytes];
	signal is_substr1[msg_bytes];
	signal is_reveal1[msg_bytes];
	signal output reveal1[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 1-th substring transitions: [(6, 7), (7, 7)]
		prev_states1[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][6];
		prev_states1[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][7];
		is_substr1[i] <== MultiOR(2)([prev_states1[0][i] * states[i+2][7], prev_states1[1][i] * states[i+2][7]]);
		is_reveal1[i] <== MultiAND(3)([out, is_substr1[i], is_consecutive[i][2]]);
		reveal1[i] <== in[i+1] * is_reveal1[i];
	}
	signal prev_states2[1][msg_bytes];
	signal is_substr2[msg_bytes];
	signal is_reveal2[msg_bytes];
	signal output reveal2[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 2-th substring transitions: [(8, 9)]
		prev_states2[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][8];
		is_substr2[i] <== MultiOR(1)([prev_states2[0][i] * states[i+2][9]]);
		is_reveal2[i] <== MultiAND(3)([out, is_substr2[i], is_consecutive[i][2]]);
		reveal2[i] <== in[i+1] * is_reveal2[i];
	}
}