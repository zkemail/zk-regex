pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: [A-Za-z0-9!#$%&'*+-/=?\^_`{\|}~\.]+@[A-Za-z0-9\.-]+
template EmailDomainRegex(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		in[i+1] <== msg[i];
	}

	component eq[25][num_bytes];
	component lt[6][num_bytes];
	component and[8][num_bytes];
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
		lt[0][i] = LessEqThan(8);
		lt[0][i].in[0] <== 65;
		lt[0][i].in[1] <== in[i];
		lt[1][i] = LessEqThan(8);
		lt[1][i].in[0] <== in[i];
		lt[1][i].in[1] <== 90;
		and[0][i] = AND();
		and[0][i].a <== lt[0][i].out;
		and[0][i].b <== lt[1][i].out;
		lt[2][i] = LessEqThan(8);
		lt[2][i].in[0] <== 94;
		lt[2][i].in[1] <== in[i];
		lt[3][i] = LessEqThan(8);
		lt[3][i].in[0] <== in[i];
		lt[3][i].in[1] <== 126;
		and[1][i] = AND();
		and[1][i].a <== lt[2][i].out;
		and[1][i].b <== lt[3][i].out;
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 33;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 35;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 36;
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 37;
		eq[4][i] = IsEqual();
		eq[4][i].in[0] <== in[i];
		eq[4][i].in[1] <== 38;
		eq[5][i] = IsEqual();
		eq[5][i].in[0] <== in[i];
		eq[5][i].in[1] <== 39;
		eq[6][i] = IsEqual();
		eq[6][i].in[0] <== in[i];
		eq[6][i].in[1] <== 42;
		eq[7][i] = IsEqual();
		eq[7][i].in[0] <== in[i];
		eq[7][i].in[1] <== 43;
		eq[8][i] = IsEqual();
		eq[8][i].in[0] <== in[i];
		eq[8][i].in[1] <== 44;
		eq[9][i] = IsEqual();
		eq[9][i].in[0] <== in[i];
		eq[9][i].in[1] <== 45;
		eq[10][i] = IsEqual();
		eq[10][i].in[0] <== in[i];
		eq[10][i].in[1] <== 46;
		eq[11][i] = IsEqual();
		eq[11][i].in[0] <== in[i];
		eq[11][i].in[1] <== 47;
		eq[12][i] = IsEqual();
		eq[12][i].in[0] <== in[i];
		eq[12][i].in[1] <== 48;
		eq[13][i] = IsEqual();
		eq[13][i].in[0] <== in[i];
		eq[13][i].in[1] <== 49;
		eq[14][i] = IsEqual();
		eq[14][i].in[0] <== in[i];
		eq[14][i].in[1] <== 50;
		eq[15][i] = IsEqual();
		eq[15][i].in[0] <== in[i];
		eq[15][i].in[1] <== 51;
		eq[16][i] = IsEqual();
		eq[16][i].in[0] <== in[i];
		eq[16][i].in[1] <== 52;
		eq[17][i] = IsEqual();
		eq[17][i].in[0] <== in[i];
		eq[17][i].in[1] <== 53;
		eq[18][i] = IsEqual();
		eq[18][i].in[0] <== in[i];
		eq[18][i].in[1] <== 54;
		eq[19][i] = IsEqual();
		eq[19][i].in[0] <== in[i];
		eq[19][i].in[1] <== 55;
		eq[20][i] = IsEqual();
		eq[20][i].in[0] <== in[i];
		eq[20][i].in[1] <== 56;
		eq[21][i] = IsEqual();
		eq[21][i].in[0] <== in[i];
		eq[21][i].in[1] <== 57;
		eq[22][i] = IsEqual();
		eq[22][i].in[0] <== in[i];
		eq[22][i].in[1] <== 61;
		eq[23][i] = IsEqual();
		eq[23][i].in[0] <== in[i];
		eq[23][i].in[1] <== 63;
		and[2][i] = AND();
		and[2][i].a <== states[i][0];
		multi_or[0][i] = MultiOR(26);
		multi_or[0][i].in[0] <== and[0][i].out;
		multi_or[0][i].in[1] <== and[1][i].out;
		multi_or[0][i].in[2] <== eq[0][i].out;
		multi_or[0][i].in[3] <== eq[1][i].out;
		multi_or[0][i].in[4] <== eq[2][i].out;
		multi_or[0][i].in[5] <== eq[3][i].out;
		multi_or[0][i].in[6] <== eq[4][i].out;
		multi_or[0][i].in[7] <== eq[5][i].out;
		multi_or[0][i].in[8] <== eq[6][i].out;
		multi_or[0][i].in[9] <== eq[7][i].out;
		multi_or[0][i].in[10] <== eq[8][i].out;
		multi_or[0][i].in[11] <== eq[9][i].out;
		multi_or[0][i].in[12] <== eq[10][i].out;
		multi_or[0][i].in[13] <== eq[11][i].out;
		multi_or[0][i].in[14] <== eq[12][i].out;
		multi_or[0][i].in[15] <== eq[13][i].out;
		multi_or[0][i].in[16] <== eq[14][i].out;
		multi_or[0][i].in[17] <== eq[15][i].out;
		multi_or[0][i].in[18] <== eq[16][i].out;
		multi_or[0][i].in[19] <== eq[17][i].out;
		multi_or[0][i].in[20] <== eq[18][i].out;
		multi_or[0][i].in[21] <== eq[19][i].out;
		multi_or[0][i].in[22] <== eq[20][i].out;
		multi_or[0][i].in[23] <== eq[21][i].out;
		multi_or[0][i].in[24] <== eq[22][i].out;
		multi_or[0][i].in[25] <== eq[23][i].out;
		and[2][i].b <== multi_or[0][i].out;
		and[3][i] = AND();
		and[3][i].a <== states[i][1];
		and[3][i].b <== multi_or[0][i].out;
		states_tmp[i+1][1] <== and[3][i].out;
		eq[24][i] = IsEqual();
		eq[24][i].in[0] <== in[i];
		eq[24][i].in[1] <== 64;
		and[4][i] = AND();
		and[4][i].a <== states[i][1];
		and[4][i].b <== eq[24][i].out;
		states[i+1][2] <== and[4][i].out;
		lt[4][i] = LessEqThan(8);
		lt[4][i].in[0] <== 97;
		lt[4][i].in[1] <== in[i];
		lt[5][i] = LessEqThan(8);
		lt[5][i].in[0] <== in[i];
		lt[5][i].in[1] <== 122;
		and[5][i] = AND();
		and[5][i].a <== lt[4][i].out;
		and[5][i].b <== lt[5][i].out;
		and[6][i] = AND();
		and[6][i].a <== states[i][2];
		multi_or[1][i] = MultiOR(14);
		multi_or[1][i].in[0] <== and[0][i].out;
		multi_or[1][i].in[1] <== and[5][i].out;
		multi_or[1][i].in[2] <== eq[9][i].out;
		multi_or[1][i].in[3] <== eq[10][i].out;
		multi_or[1][i].in[4] <== eq[12][i].out;
		multi_or[1][i].in[5] <== eq[13][i].out;
		multi_or[1][i].in[6] <== eq[14][i].out;
		multi_or[1][i].in[7] <== eq[15][i].out;
		multi_or[1][i].in[8] <== eq[16][i].out;
		multi_or[1][i].in[9] <== eq[17][i].out;
		multi_or[1][i].in[10] <== eq[18][i].out;
		multi_or[1][i].in[11] <== eq[19][i].out;
		multi_or[1][i].in[12] <== eq[20][i].out;
		multi_or[1][i].in[13] <== eq[21][i].out;
		and[6][i].b <== multi_or[1][i].out;
		and[7][i] = AND();
		and[7][i].a <== states[i][3];
		and[7][i].b <== multi_or[1][i].out;
		multi_or[2][i] = MultiOR(2);
		multi_or[2][i].in[0] <== and[6][i].out;
		multi_or[2][i].in[1] <== and[7][i].out;
		states[i+1][3] <== multi_or[2][i].out;
		from_zero_enabled[i] <== MultiNOR(3)([states_tmp[i+1][1], states[i+1][2], states[i+1][3]]);
		states[i+1][1] <== MultiOR(2)([states_tmp[i+1][1], from_zero_enabled[i] * and[2][i].out]);
		state_changed[i].in[0] <== states[i+1][1];
		state_changed[i].in[1] <== states[i+1][2];
		state_changed[i].in[2] <== states[i+1][3];
	}

	component is_accepted = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		is_accepted.in[i] <== states[i][3];
	}
	out <== is_accepted.out;
	signal is_consecutive[msg_bytes+1][3];
	is_consecutive[msg_bytes][2] <== 0;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][3] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
		is_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][3], is_consecutive[msg_bytes-1-i][1]]);
	}
	// substrings calculated: [{(2, 3), (3, 3)}]
	signal prev_states0[2][msg_bytes];
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(2, 3), (3, 3)]
		prev_states0[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][2];
		prev_states0[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][3];
		is_substr0[i] <== MultiOR(2)([prev_states0[0][i] * states[i+2][3], prev_states0[1][i] * states[i+2][3]]);
		is_reveal0[i] <== MultiAND(3)([out, is_substr0[i], is_consecutive[i][2]]);
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
}