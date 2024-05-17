pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (1x?2)+b
template Question2Regex(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		in[i+1] <== msg[i];
	}

	component eq[4][num_bytes];
	component and[6][num_bytes];
	component multi_or[1][num_bytes];
	signal states[num_bytes+1][5];
	signal states_tmp[num_bytes+1][5];
	signal from_zero_enabled[num_bytes+1];
	from_zero_enabled[num_bytes] <== 0;
	component state_changed[num_bytes];

	for (var i = 1; i < 5; i++) {
		states[0][i] <== 0;
	}

	for (var i = 0; i < num_bytes; i++) {
		state_changed[i] = MultiOR(4);
		states[i][0] <== 1;
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 49;
		and[0][i] = AND();
		and[0][i].a <== states[i][0];
		and[0][i].b <== eq[0][i].out;
		and[1][i] = AND();
		and[1][i].a <== states[i][2];
		and[1][i].b <== eq[0][i].out;
		states_tmp[i+1][1] <== and[1][i].out;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 50;
		and[2][i] = AND();
		and[2][i].a <== states[i][1];
		and[2][i].b <== eq[1][i].out;
		and[3][i] = AND();
		and[3][i].a <== states[i][3];
		and[3][i].b <== eq[1][i].out;
		multi_or[0][i] = MultiOR(2);
		multi_or[0][i].in[0] <== and[2][i].out;
		multi_or[0][i].in[1] <== and[3][i].out;
		states[i+1][2] <== multi_or[0][i].out;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 120;
		and[4][i] = AND();
		and[4][i].a <== states[i][1];
		and[4][i].b <== eq[2][i].out;
		states[i+1][3] <== and[4][i].out;
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 98;
		and[5][i] = AND();
		and[5][i].a <== states[i][2];
		and[5][i].b <== eq[3][i].out;
		states[i+1][4] <== and[5][i].out;
		from_zero_enabled[i] <== MultiNOR(4)([states_tmp[i+1][1], states[i+1][2], states[i+1][3], states[i+1][4]]);
		states[i+1][1] <== MultiOR(2)([states_tmp[i+1][1], from_zero_enabled[i] * and[0][i].out]);
		state_changed[i].in[0] <== states[i+1][1];
		state_changed[i].in[1] <== states[i+1][2];
		state_changed[i].in[2] <== states[i+1][3];
		state_changed[i].in[3] <== states[i+1][4];
	}

	component is_accepted = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		is_accepted.in[i] <== states[i][4];
	}
	out <== is_accepted.out;
	signal is_consecutive[msg_bytes+1][3];
	is_consecutive[msg_bytes][2] <== 0;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][4] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
		is_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][4], is_consecutive[msg_bytes-1-i][1]]);
	}
	// substrings calculated: [{(0, 1), (1, 2), (1, 3), (2, 1), (3, 2)}]
	signal prev_states0[5][msg_bytes];
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(0, 1), (1, 2), (1, 3), (2, 1), (3, 2)]
		prev_states0[0][i] <== from_zero_enabled[i+1] * states[i+1][0];
		prev_states0[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][1];
		prev_states0[2][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][1];
		prev_states0[3][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][2];
		prev_states0[4][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][3];
		is_substr0[i] <== MultiOR(5)([prev_states0[0][i] * states[i+2][1], prev_states0[1][i] * states[i+2][2], prev_states0[2][i] * states[i+2][3], prev_states0[3][i] * states[i+2][1], prev_states0[4][i] * states[i+2][2]]);
		is_reveal0[i] <== MultiAND(3)([out, is_substr0[i], is_consecutive[i][2]]);
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
}