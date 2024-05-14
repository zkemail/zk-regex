pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (\n|^)[^abc]+
template Caret5Regex(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		in[i+1] <== msg[i];
	}

	component eq[15][num_bytes];
	component and[23][num_bytes];
	component multi_or[8][num_bytes];
	signal states[num_bytes+1][9];
	signal states_tmp[num_bytes+1][9];
	signal from_zero_enabled[num_bytes+1];
	from_zero_enabled[num_bytes] <== 0;
	component state_changed[num_bytes];

	for (var i = 1; i < 9; i++) {
		states[0][i] <== 0;
	}

	for (var i = 0; i < num_bytes; i++) {
		state_changed[i] = MultiOR(8);
		states[i][0] <== 1;
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 0;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 1;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 2;
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 4;
		and[0][i] = AND();
		and[0][i].a <== states[i][0];
		multi_or[0][i] = MultiOR(4);
		multi_or[0][i].in[0] <== eq[0][i].out;
		multi_or[0][i].in[1] <== eq[1][i].out;
		multi_or[0][i].in[2] <== eq[2][i].out;
		multi_or[0][i].in[3] <== eq[3][i].out;
		and[0][i].b <== multi_or[0][i].out;
		and[1][i] = AND();
		and[1][i].a <== states[i][1];
		and[1][i].b <== multi_or[0][i].out;
		eq[4][i] = IsEqual();
		eq[4][i].in[0] <== in[i];
		eq[4][i].in[1] <== 5;
		eq[5][i] = IsEqual();
		eq[5][i].in[0] <== in[i];
		eq[5][i].in[1] <== 6;
		eq[6][i] = IsEqual();
		eq[6][i].in[0] <== in[i];
		eq[6][i].in[1] <== 7;
		and[2][i] = AND();
		and[2][i].a <== states[i][2];
		multi_or[1][i] = MultiOR(3);
		multi_or[1][i].in[0] <== eq[4][i].out;
		multi_or[1][i].in[1] <== eq[5][i].out;
		multi_or[1][i].in[2] <== eq[6][i].out;
		and[2][i].b <== multi_or[1][i].out;
		multi_or[2][i] = MultiOR(2);
		multi_or[2][i].in[0] <== and[1][i].out;
		multi_or[2][i].in[1] <== and[2][i].out;
		states_tmp[i+1][1] <== multi_or[2][i].out;
		eq[7][i] = IsEqual();
		eq[7][i].in[0] <== in[i];
		eq[7][i].in[1] <== 9;
		and[3][i] = AND();
		and[3][i].a <== states[i][0];
		and[3][i].b <== eq[7][i].out;
		and[4][i] = AND();
		and[4][i].a <== states[i][1];
		and[4][i].b <== eq[7][i].out;
		and[5][i] = AND();
		and[5][i].a <== states[i][3];
		and[5][i].b <== eq[6][i].out;
		and[6][i] = AND();
		and[6][i].a <== states[i][4];
		and[6][i].b <== multi_or[1][i].out;
		and[7][i] = AND();
		and[7][i].a <== states[i][5];
		multi_or[3][i] = MultiOR(2);
		multi_or[3][i].in[0] <== eq[4][i].out;
		multi_or[3][i].in[1] <== eq[5][i].out;
		and[7][i].b <== multi_or[3][i].out;
		multi_or[4][i] = MultiOR(4);
		multi_or[4][i].in[0] <== and[4][i].out;
		multi_or[4][i].in[1] <== and[5][i].out;
		multi_or[4][i].in[2] <== and[6][i].out;
		multi_or[4][i].in[3] <== and[7][i].out;
		states_tmp[i+1][2] <== multi_or[4][i].out;
		eq[8][i] = IsEqual();
		eq[8][i].in[0] <== in[i];
		eq[8][i].in[1] <== 10;
		and[8][i] = AND();
		and[8][i].a <== states[i][0];
		and[8][i].b <== eq[8][i].out;
		and[9][i] = AND();
		and[9][i].a <== states[i][1];
		and[9][i].b <== eq[8][i].out;
		states_tmp[i+1][3] <== and[9][i].out;
		eq[9][i] = IsEqual();
		eq[9][i].in[0] <== in[i];
		eq[9][i].in[1] <== 11;
		eq[10][i] = IsEqual();
		eq[10][i].in[0] <== in[i];
		eq[10][i].in[1] <== 13;
		and[10][i] = AND();
		and[10][i].a <== states[i][0];
		multi_or[5][i] = MultiOR(2);
		multi_or[5][i].in[0] <== eq[9][i].out;
		multi_or[5][i].in[1] <== eq[10][i].out;
		and[10][i].b <== multi_or[5][i].out;
		and[11][i] = AND();
		and[11][i].a <== states[i][1];
		and[11][i].b <== multi_or[5][i].out;
		and[12][i] = AND();
		and[12][i].a <== states[i][6];
		multi_or[6][i] = MultiOR(2);
		multi_or[6][i].in[0] <== eq[5][i].out;
		multi_or[6][i].in[1] <== eq[6][i].out;
		and[12][i].b <== multi_or[6][i].out;
		and[13][i] = AND();
		and[13][i].a <== states[i][7];
		and[13][i].b <== multi_or[1][i].out;
		and[14][i] = AND();
		and[14][i].a <== states[i][8];
		and[14][i].b <== eq[4][i].out;
		multi_or[7][i] = MultiOR(4);
		multi_or[7][i].in[0] <== and[11][i].out;
		multi_or[7][i].in[1] <== and[12][i].out;
		multi_or[7][i].in[2] <== and[13][i].out;
		multi_or[7][i].in[3] <== and[14][i].out;
		states_tmp[i+1][4] <== multi_or[7][i].out;
		eq[11][i] = IsEqual();
		eq[11][i].in[0] <== in[i];
		eq[11][i].in[1] <== 12;
		and[15][i] = AND();
		and[15][i].a <== states[i][0];
		and[15][i].b <== eq[11][i].out;
		and[16][i] = AND();
		and[16][i].a <== states[i][1];
		and[16][i].b <== eq[11][i].out;
		states_tmp[i+1][5] <== and[16][i].out;
		eq[12][i] = IsEqual();
		eq[12][i].in[0] <== in[i];
		eq[12][i].in[1] <== 14;
		and[17][i] = AND();
		and[17][i].a <== states[i][0];
		and[17][i].b <== eq[12][i].out;
		and[18][i] = AND();
		and[18][i].a <== states[i][1];
		and[18][i].b <== eq[12][i].out;
		states_tmp[i+1][6] <== and[18][i].out;
		eq[13][i] = IsEqual();
		eq[13][i].in[0] <== in[i];
		eq[13][i].in[1] <== 15;
		and[19][i] = AND();
		and[19][i].a <== states[i][0];
		and[19][i].b <== eq[13][i].out;
		and[20][i] = AND();
		and[20][i].a <== states[i][1];
		and[20][i].b <== eq[13][i].out;
		states_tmp[i+1][7] <== and[20][i].out;
		eq[14][i] = IsEqual();
		eq[14][i].in[0] <== in[i];
		eq[14][i].in[1] <== 16;
		and[21][i] = AND();
		and[21][i].a <== states[i][0];
		and[21][i].b <== eq[14][i].out;
		and[22][i] = AND();
		and[22][i].a <== states[i][1];
		and[22][i].b <== eq[14][i].out;
		states_tmp[i+1][8] <== and[22][i].out;
		from_zero_enabled[i] <== MultiNOR(8)([states_tmp[i+1][1], states_tmp[i+1][2], states_tmp[i+1][3], states_tmp[i+1][4], states_tmp[i+1][5], states_tmp[i+1][6], states_tmp[i+1][7], states_tmp[i+1][8]]);
		states[i+1][1] <== MultiOR(2)([states_tmp[i+1][1], from_zero_enabled[i] * and[0][i].out]);
		states[i+1][2] <== MultiOR(2)([states_tmp[i+1][2], from_zero_enabled[i] * and[3][i].out]);
		states[i+1][3] <== MultiOR(2)([states_tmp[i+1][3], from_zero_enabled[i] * and[8][i].out]);
		states[i+1][4] <== MultiOR(2)([states_tmp[i+1][4], from_zero_enabled[i] * and[10][i].out]);
		states[i+1][5] <== MultiOR(2)([states_tmp[i+1][5], from_zero_enabled[i] * and[15][i].out]);
		states[i+1][6] <== MultiOR(2)([states_tmp[i+1][6], from_zero_enabled[i] * and[17][i].out]);
		states[i+1][7] <== MultiOR(2)([states_tmp[i+1][7], from_zero_enabled[i] * and[19][i].out]);
		states[i+1][8] <== MultiOR(2)([states_tmp[i+1][8], from_zero_enabled[i] * and[21][i].out]);
		state_changed[i].in[0] <== states[i+1][1];
		state_changed[i].in[1] <== states[i+1][2];
		state_changed[i].in[2] <== states[i+1][3];
		state_changed[i].in[3] <== states[i+1][4];
		state_changed[i].in[4] <== states[i+1][5];
		state_changed[i].in[5] <== states[i+1][6];
		state_changed[i].in[6] <== states[i+1][7];
		state_changed[i].in[7] <== states[i+1][8];
	}

	component final_state_result = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		final_state_result.in[i] <== states[i][1];
	}
	out <== final_state_result.out;
	signal is_consecutive[msg_bytes+1][3];
	is_consecutive[msg_bytes][2] <== 0;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][1] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
		is_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][1], is_consecutive[msg_bytes-1-i][1]]);
	}
	// substrings calculated: [{(0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (0, 7), (0, 8), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (2, 1), (3, 2), (4, 2), (5, 2), (6, 4), (7, 4), (8, 4)}]
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (0, 7), (0, 8), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (2, 1), (3, 2), (4, 2), (5, 2), (6, 4), (7, 4), (8, 4)]
		is_substr0[i] <== MultiOR(23)([states[i+1][0] * states[i+2][1], states[i+1][0] * states[i+2][2], states[i+1][0] * states[i+2][3], states[i+1][0] * states[i+2][4], states[i+1][0] * states[i+2][5], states[i+1][0] * states[i+2][6], states[i+1][0] * states[i+2][7], states[i+1][0] * states[i+2][8], states[i+1][1] * states[i+2][1], states[i+1][1] * states[i+2][2], states[i+1][1] * states[i+2][3], states[i+1][1] * states[i+2][4], states[i+1][1] * states[i+2][5], states[i+1][1] * states[i+2][6], states[i+1][1] * states[i+2][7], states[i+1][1] * states[i+2][8], states[i+1][2] * states[i+2][1], states[i+1][3] * states[i+2][2], states[i+1][4] * states[i+2][2], states[i+1][5] * states[i+2][2], states[i+1][6] * states[i+2][4], states[i+1][7] * states[i+2][4], states[i+1][8] * states[i+2][4]]);
		is_reveal0[i] <== is_substr0[i] * is_consecutive[i][2];
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
}