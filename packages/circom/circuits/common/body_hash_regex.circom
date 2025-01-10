pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (\r\n|^)dkim-signature:([a-z]+=[^;]+; )+bh=[a-zA-Z0-9+/=]+;
template BodyHashRegex(msg_bytes, is_safe) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	signal in_range_checks[msg_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		if is_safe {
			in_range_checks[i] <== SemiSafeLessThan(8)([msg[i], 255]);
		} else {
			in_range_checks[i] <== LessThan(8)([msg[i], 255]);
		}
		in_range_checks[i] === 1;
		in[i+1] <== msg[i];
	}

	component eq[90][num_bytes];
	component lt[24][num_bytes];
	component and[76][num_bytes];
	component multi_or[19][num_bytes];
	signal states[num_bytes+1][35];
	signal states_tmp[num_bytes+1][35];
	signal from_zero_enabled[num_bytes+1];
	from_zero_enabled[num_bytes] <== 0;
	component state_changed[num_bytes];

	for (var i = 1; i < 35; i++) {
		states[0][i] <== 0;
	}

	for (var i = 0; i < num_bytes; i++) {
		state_changed[i] = MultiOR(34);
		states[i][0] <== 1;
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 13;
		and[0][i] = AND();
		and[0][i].a <== states[i][0];
		and[0][i].b <== eq[0][i].out;
		states_tmp[i+1][1] <== 0;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 255;
		and[1][i] = AND();
		and[1][i].a <== states[i][0];
		and[1][i].b <== eq[1][i].out;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 10;
		and[2][i] = AND();
		and[2][i].a <== states[i][1];
		and[2][i].b <== eq[2][i].out;
		states_tmp[i+1][2] <== and[2][i].out;
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 100;
		and[3][i] = AND();
		and[3][i].a <== states[i][2];
		and[3][i].b <== eq[3][i].out;
		states[i+1][3] <== and[3][i].out;
		eq[4][i] = IsEqual();
		eq[4][i].in[0] <== in[i];
		eq[4][i].in[1] <== 107;
		and[4][i] = AND();
		and[4][i].a <== states[i][3];
		and[4][i].b <== eq[4][i].out;
		states[i+1][4] <== and[4][i].out;
		eq[5][i] = IsEqual();
		eq[5][i].in[0] <== in[i];
		eq[5][i].in[1] <== 105;
		and[5][i] = AND();
		and[5][i].a <== states[i][4];
		and[5][i].b <== eq[5][i].out;
		states[i+1][5] <== and[5][i].out;
		eq[6][i] = IsEqual();
		eq[6][i].in[0] <== in[i];
		eq[6][i].in[1] <== 109;
		and[6][i] = AND();
		and[6][i].a <== states[i][5];
		and[6][i].b <== eq[6][i].out;
		states[i+1][6] <== and[6][i].out;
		eq[7][i] = IsEqual();
		eq[7][i].in[0] <== in[i];
		eq[7][i].in[1] <== 45;
		and[7][i] = AND();
		and[7][i].a <== states[i][6];
		and[7][i].b <== eq[7][i].out;
		states[i+1][7] <== and[7][i].out;
		eq[8][i] = IsEqual();
		eq[8][i].in[0] <== in[i];
		eq[8][i].in[1] <== 115;
		and[8][i] = AND();
		and[8][i].a <== states[i][7];
		and[8][i].b <== eq[8][i].out;
		states[i+1][8] <== and[8][i].out;
		and[9][i] = AND();
		and[9][i].a <== states[i][8];
		and[9][i].b <== eq[5][i].out;
		states[i+1][9] <== and[9][i].out;
		eq[9][i] = IsEqual();
		eq[9][i].in[0] <== in[i];
		eq[9][i].in[1] <== 103;
		and[10][i] = AND();
		and[10][i].a <== states[i][9];
		and[10][i].b <== eq[9][i].out;
		states[i+1][10] <== and[10][i].out;
		eq[10][i] = IsEqual();
		eq[10][i].in[0] <== in[i];
		eq[10][i].in[1] <== 110;
		and[11][i] = AND();
		and[11][i].a <== states[i][10];
		and[11][i].b <== eq[10][i].out;
		states[i+1][11] <== and[11][i].out;
		eq[11][i] = IsEqual();
		eq[11][i].in[0] <== in[i];
		eq[11][i].in[1] <== 97;
		and[12][i] = AND();
		and[12][i].a <== states[i][11];
		and[12][i].b <== eq[11][i].out;
		states[i+1][12] <== and[12][i].out;
		eq[12][i] = IsEqual();
		eq[12][i].in[0] <== in[i];
		eq[12][i].in[1] <== 116;
		and[13][i] = AND();
		and[13][i].a <== states[i][12];
		and[13][i].b <== eq[12][i].out;
		states[i+1][13] <== and[13][i].out;
		eq[13][i] = IsEqual();
		eq[13][i].in[0] <== in[i];
		eq[13][i].in[1] <== 117;
		and[14][i] = AND();
		and[14][i].a <== states[i][13];
		and[14][i].b <== eq[13][i].out;
		states[i+1][14] <== and[14][i].out;
		eq[14][i] = IsEqual();
		eq[14][i].in[0] <== in[i];
		eq[14][i].in[1] <== 114;
		and[15][i] = AND();
		and[15][i].a <== states[i][14];
		and[15][i].b <== eq[14][i].out;
		states[i+1][15] <== and[15][i].out;
		eq[15][i] = IsEqual();
		eq[15][i].in[0] <== in[i];
		eq[15][i].in[1] <== 101;
		and[16][i] = AND();
		and[16][i].a <== states[i][15];
		and[16][i].b <== eq[15][i].out;
		states[i+1][16] <== and[16][i].out;
		eq[16][i] = IsEqual();
		eq[16][i].in[0] <== in[i];
		eq[16][i].in[1] <== 58;
		and[17][i] = AND();
		and[17][i].a <== states[i][16];
		and[17][i].b <== eq[16][i].out;
		states[i+1][17] <== and[17][i].out;
		lt[0][i] = LessEqThan(8);
		lt[0][i].in[0] <== 97;
		lt[0][i].in[1] <== in[i];
		lt[1][i] = LessEqThan(8);
		lt[1][i].in[0] <== in[i];
		lt[1][i].in[1] <== 122;
		and[18][i] = AND();
		and[18][i].a <== lt[0][i].out;
		and[18][i].b <== lt[1][i].out;
		and[19][i] = AND();
		and[19][i].a <== states[i][17];
		and[19][i].b <== and[18][i].out;
		and[20][i] = AND();
		and[20][i].a <== states[i][18];
		and[20][i].b <== and[18][i].out;
		lt[2][i] = LessEqThan(8);
		lt[2][i].in[0] <== 99;
		lt[2][i].in[1] <== in[i];
		lt[3][i] = LessEqThan(8);
		lt[3][i].in[0] <== in[i];
		lt[3][i].in[1] <== 122;
		and[21][i] = AND();
		and[21][i].a <== lt[2][i].out;
		and[21][i].b <== lt[3][i].out;
		and[22][i] = AND();
		and[22][i].a <== states[i][29];
		multi_or[0][i] = MultiOR(2);
		multi_or[0][i].in[0] <== and[21][i].out;
		multi_or[0][i].in[1] <== eq[11][i].out;
		and[22][i].b <== multi_or[0][i].out;
		lt[4][i] = LessEqThan(8);
		lt[4][i].in[0] <== 105;
		lt[4][i].in[1] <== in[i];
		lt[5][i] = LessEqThan(8);
		lt[5][i].in[0] <== in[i];
		lt[5][i].in[1] <== 122;
		and[23][i] = AND();
		and[23][i].a <== lt[4][i].out;
		and[23][i].b <== lt[5][i].out;
		eq[17][i] = IsEqual();
		eq[17][i].in[0] <== in[i];
		eq[17][i].in[1] <== 98;
		eq[18][i] = IsEqual();
		eq[18][i].in[0] <== in[i];
		eq[18][i].in[1] <== 99;
		eq[19][i] = IsEqual();
		eq[19][i].in[0] <== in[i];
		eq[19][i].in[1] <== 102;
		and[24][i] = AND();
		and[24][i].a <== states[i][30];
		multi_or[1][i] = MultiOR(8);
		multi_or[1][i].in[0] <== and[23][i].out;
		multi_or[1][i].in[1] <== eq[11][i].out;
		multi_or[1][i].in[2] <== eq[17][i].out;
		multi_or[1][i].in[3] <== eq[18][i].out;
		multi_or[1][i].in[4] <== eq[3][i].out;
		multi_or[1][i].in[5] <== eq[15][i].out;
		multi_or[1][i].in[6] <== eq[19][i].out;
		multi_or[1][i].in[7] <== eq[9][i].out;
		and[24][i].b <== multi_or[1][i].out;
		and[25][i] = AND();
		and[25][i].a <== states[i][31];
		and[25][i].b <== and[18][i].out;
		multi_or[2][i] = MultiOR(5);
		multi_or[2][i].in[0] <== and[19][i].out;
		multi_or[2][i].in[1] <== and[20][i].out;
		multi_or[2][i].in[2] <== and[22][i].out;
		multi_or[2][i].in[3] <== and[24][i].out;
		multi_or[2][i].in[4] <== and[25][i].out;
		states[i+1][18] <== multi_or[2][i].out;
		eq[20][i] = IsEqual();
		eq[20][i].in[0] <== in[i];
		eq[20][i].in[1] <== 61;
		and[26][i] = AND();
		and[26][i].a <== states[i][18];
		and[26][i].b <== eq[20][i].out;
		and[27][i] = AND();
		and[27][i].a <== states[i][30];
		and[27][i].b <== eq[20][i].out;
		multi_or[3][i] = MultiOR(2);
		multi_or[3][i].in[0] <== and[26][i].out;
		multi_or[3][i].in[1] <== and[27][i].out;
		states[i+1][19] <== multi_or[3][i].out;
		lt[6][i] = LessEqThan(8);
		lt[6][i].in[0] <== 1;
		lt[6][i].in[1] <== in[i];
		lt[7][i] = LessEqThan(8);
		lt[7][i].in[0] <== in[i];
		lt[7][i].in[1] <== 58;
		and[28][i] = AND();
		and[28][i].a <== lt[6][i].out;
		and[28][i].b <== lt[7][i].out;
		lt[8][i] = LessEqThan(8);
		lt[8][i].in[0] <== 60;
		lt[8][i].in[1] <== in[i];
		lt[9][i] = LessEqThan(8);
		lt[9][i].in[0] <== in[i];
		lt[9][i].in[1] <== 127;
		and[29][i] = AND();
		and[29][i].a <== lt[8][i].out;
		and[29][i].b <== lt[9][i].out;
		and[30][i] = AND();
		and[30][i].a <== states[i][19];
		multi_or[4][i] = MultiOR(2);
		multi_or[4][i].in[0] <== and[28][i].out;
		multi_or[4][i].in[1] <== and[29][i].out;
		and[30][i].b <== multi_or[4][i].out;
		and[31][i] = AND();
		and[31][i].a <== states[i][20];
		and[31][i].b <== multi_or[4][i].out;
		lt[10][i] = LessEqThan(8);
		lt[10][i].in[0] <== 128;
		lt[10][i].in[1] <== in[i];
		lt[11][i] = LessEqThan(8);
		lt[11][i].in[0] <== in[i];
		lt[11][i].in[1] <== 191;
		and[32][i] = AND();
		and[32][i].a <== lt[10][i].out;
		and[32][i].b <== lt[11][i].out;
		and[33][i] = AND();
		and[33][i].a <== states[i][21];
		and[33][i].b <== and[32][i].out;
		lt[12][i] = LessEqThan(8);
		lt[12][i].in[0] <== 1;
		lt[12][i].in[1] <== in[i];
		lt[13][i] = LessEqThan(8);
		lt[13][i].in[0] <== in[i];
		lt[13][i].in[1] <== 42;
		and[34][i] = AND();
		and[34][i].a <== lt[12][i].out;
		and[34][i].b <== lt[13][i].out;
		eq[21][i] = IsEqual();
		eq[21][i].in[0] <== in[i];
		eq[21][i].in[1] <== 44;
		eq[22][i] = IsEqual();
		eq[22][i].in[0] <== in[i];
		eq[22][i].in[1] <== 46;
		eq[23][i] = IsEqual();
		eq[23][i].in[0] <== in[i];
		eq[23][i].in[1] <== 60;
		eq[24][i] = IsEqual();
		eq[24][i].in[0] <== in[i];
		eq[24][i].in[1] <== 62;
		eq[25][i] = IsEqual();
		eq[25][i].in[0] <== in[i];
		eq[25][i].in[1] <== 63;
		eq[26][i] = IsEqual();
		eq[26][i].in[0] <== in[i];
		eq[26][i].in[1] <== 64;
		eq[27][i] = IsEqual();
		eq[27][i].in[0] <== in[i];
		eq[27][i].in[1] <== 91;
		eq[28][i] = IsEqual();
		eq[28][i].in[0] <== in[i];
		eq[28][i].in[1] <== 92;
		eq[29][i] = IsEqual();
		eq[29][i].in[0] <== in[i];
		eq[29][i].in[1] <== 93;
		eq[30][i] = IsEqual();
		eq[30][i].in[0] <== in[i];
		eq[30][i].in[1] <== 94;
		eq[31][i] = IsEqual();
		eq[31][i].in[0] <== in[i];
		eq[31][i].in[1] <== 95;
		eq[32][i] = IsEqual();
		eq[32][i].in[0] <== in[i];
		eq[32][i].in[1] <== 96;
		eq[33][i] = IsEqual();
		eq[33][i].in[0] <== in[i];
		eq[33][i].in[1] <== 123;
		eq[34][i] = IsEqual();
		eq[34][i].in[0] <== in[i];
		eq[34][i].in[1] <== 124;
		eq[35][i] = IsEqual();
		eq[35][i].in[0] <== in[i];
		eq[35][i].in[1] <== 125;
		eq[36][i] = IsEqual();
		eq[36][i].in[0] <== in[i];
		eq[36][i].in[1] <== 126;
		eq[37][i] = IsEqual();
		eq[37][i].in[0] <== in[i];
		eq[37][i].in[1] <== 127;
		and[35][i] = AND();
		and[35][i].a <== states[i][32];
		multi_or[5][i] = MultiOR(20);
		multi_or[5][i].in[0] <== and[34][i].out;
		multi_or[5][i].in[1] <== eq[21][i].out;
		multi_or[5][i].in[2] <== eq[7][i].out;
		multi_or[5][i].in[3] <== eq[22][i].out;
		multi_or[5][i].in[4] <== eq[16][i].out;
		multi_or[5][i].in[5] <== eq[23][i].out;
		multi_or[5][i].in[6] <== eq[24][i].out;
		multi_or[5][i].in[7] <== eq[25][i].out;
		multi_or[5][i].in[8] <== eq[26][i].out;
		multi_or[5][i].in[9] <== eq[27][i].out;
		multi_or[5][i].in[10] <== eq[28][i].out;
		multi_or[5][i].in[11] <== eq[29][i].out;
		multi_or[5][i].in[12] <== eq[30][i].out;
		multi_or[5][i].in[13] <== eq[31][i].out;
		multi_or[5][i].in[14] <== eq[32][i].out;
		multi_or[5][i].in[15] <== eq[33][i].out;
		multi_or[5][i].in[16] <== eq[34][i].out;
		multi_or[5][i].in[17] <== eq[35][i].out;
		multi_or[5][i].in[18] <== eq[36][i].out;
		multi_or[5][i].in[19] <== eq[37][i].out;
		and[35][i].b <== multi_or[5][i].out;
		multi_or[6][i] = MultiOR(4);
		multi_or[6][i].in[0] <== and[30][i].out;
		multi_or[6][i].in[1] <== and[31][i].out;
		multi_or[6][i].in[2] <== and[33][i].out;
		multi_or[6][i].in[3] <== and[35][i].out;
		states[i+1][20] <== multi_or[6][i].out;
		lt[14][i] = LessEqThan(8);
		lt[14][i].in[0] <== 194;
		lt[14][i].in[1] <== in[i];
		lt[15][i] = LessEqThan(8);
		lt[15][i].in[0] <== in[i];
		lt[15][i].in[1] <== 223;
		and[36][i] = AND();
		and[36][i].a <== lt[14][i].out;
		and[36][i].b <== lt[15][i].out;
		and[37][i] = AND();
		and[37][i].a <== states[i][19];
		and[37][i].b <== and[36][i].out;
		and[38][i] = AND();
		and[38][i].a <== states[i][20];
		and[38][i].b <== and[36][i].out;
		lt[16][i] = LessEqThan(8);
		lt[16][i].in[0] <== 160;
		lt[16][i].in[1] <== in[i];
		lt[17][i] = LessEqThan(8);
		lt[17][i].in[0] <== in[i];
		lt[17][i].in[1] <== 191;
		and[39][i] = AND();
		and[39][i].a <== lt[16][i].out;
		and[39][i].b <== lt[17][i].out;
		and[40][i] = AND();
		and[40][i].a <== states[i][22];
		and[40][i].b <== and[39][i].out;
		and[41][i] = AND();
		and[41][i].a <== states[i][23];
		and[41][i].b <== and[32][i].out;
		lt[18][i] = LessEqThan(8);
		lt[18][i].in[0] <== 128;
		lt[18][i].in[1] <== in[i];
		lt[19][i] = LessEqThan(8);
		lt[19][i].in[0] <== in[i];
		lt[19][i].in[1] <== 159;
		and[42][i] = AND();
		and[42][i].a <== lt[18][i].out;
		and[42][i].b <== lt[19][i].out;
		and[43][i] = AND();
		and[43][i].a <== states[i][24];
		and[43][i].b <== and[42][i].out;
		and[44][i] = AND();
		and[44][i].a <== states[i][32];
		and[44][i].b <== and[36][i].out;
		multi_or[7][i] = MultiOR(6);
		multi_or[7][i].in[0] <== and[37][i].out;
		multi_or[7][i].in[1] <== and[38][i].out;
		multi_or[7][i].in[2] <== and[40][i].out;
		multi_or[7][i].in[3] <== and[41][i].out;
		multi_or[7][i].in[4] <== and[43][i].out;
		multi_or[7][i].in[5] <== and[44][i].out;
		states[i+1][21] <== multi_or[7][i].out;
		eq[38][i] = IsEqual();
		eq[38][i].in[0] <== in[i];
		eq[38][i].in[1] <== 224;
		and[45][i] = AND();
		and[45][i].a <== states[i][19];
		and[45][i].b <== eq[38][i].out;
		and[46][i] = AND();
		and[46][i].a <== states[i][20];
		and[46][i].b <== eq[38][i].out;
		and[47][i] = AND();
		and[47][i].a <== states[i][32];
		and[47][i].b <== eq[38][i].out;
		multi_or[8][i] = MultiOR(3);
		multi_or[8][i].in[0] <== and[45][i].out;
		multi_or[8][i].in[1] <== and[46][i].out;
		multi_or[8][i].in[2] <== and[47][i].out;
		states[i+1][22] <== multi_or[8][i].out;
		eq[39][i] = IsEqual();
		eq[39][i].in[0] <== in[i];
		eq[39][i].in[1] <== 225;
		eq[40][i] = IsEqual();
		eq[40][i].in[0] <== in[i];
		eq[40][i].in[1] <== 226;
		eq[41][i] = IsEqual();
		eq[41][i].in[0] <== in[i];
		eq[41][i].in[1] <== 227;
		eq[42][i] = IsEqual();
		eq[42][i].in[0] <== in[i];
		eq[42][i].in[1] <== 228;
		eq[43][i] = IsEqual();
		eq[43][i].in[0] <== in[i];
		eq[43][i].in[1] <== 229;
		eq[44][i] = IsEqual();
		eq[44][i].in[0] <== in[i];
		eq[44][i].in[1] <== 230;
		eq[45][i] = IsEqual();
		eq[45][i].in[0] <== in[i];
		eq[45][i].in[1] <== 231;
		eq[46][i] = IsEqual();
		eq[46][i].in[0] <== in[i];
		eq[46][i].in[1] <== 232;
		eq[47][i] = IsEqual();
		eq[47][i].in[0] <== in[i];
		eq[47][i].in[1] <== 233;
		eq[48][i] = IsEqual();
		eq[48][i].in[0] <== in[i];
		eq[48][i].in[1] <== 234;
		eq[49][i] = IsEqual();
		eq[49][i].in[0] <== in[i];
		eq[49][i].in[1] <== 235;
		eq[50][i] = IsEqual();
		eq[50][i].in[0] <== in[i];
		eq[50][i].in[1] <== 236;
		eq[51][i] = IsEqual();
		eq[51][i].in[0] <== in[i];
		eq[51][i].in[1] <== 238;
		eq[52][i] = IsEqual();
		eq[52][i].in[0] <== in[i];
		eq[52][i].in[1] <== 239;
		and[48][i] = AND();
		and[48][i].a <== states[i][19];
		multi_or[9][i] = MultiOR(14);
		multi_or[9][i].in[0] <== eq[39][i].out;
		multi_or[9][i].in[1] <== eq[40][i].out;
		multi_or[9][i].in[2] <== eq[41][i].out;
		multi_or[9][i].in[3] <== eq[42][i].out;
		multi_or[9][i].in[4] <== eq[43][i].out;
		multi_or[9][i].in[5] <== eq[44][i].out;
		multi_or[9][i].in[6] <== eq[45][i].out;
		multi_or[9][i].in[7] <== eq[46][i].out;
		multi_or[9][i].in[8] <== eq[47][i].out;
		multi_or[9][i].in[9] <== eq[48][i].out;
		multi_or[9][i].in[10] <== eq[49][i].out;
		multi_or[9][i].in[11] <== eq[50][i].out;
		multi_or[9][i].in[12] <== eq[51][i].out;
		multi_or[9][i].in[13] <== eq[52][i].out;
		and[48][i].b <== multi_or[9][i].out;
		and[49][i] = AND();
		and[49][i].a <== states[i][20];
		and[49][i].b <== multi_or[9][i].out;
		lt[20][i] = LessEqThan(8);
		lt[20][i].in[0] <== 144;
		lt[20][i].in[1] <== in[i];
		lt[21][i] = LessEqThan(8);
		lt[21][i].in[0] <== in[i];
		lt[21][i].in[1] <== 191;
		and[50][i] = AND();
		and[50][i].a <== lt[20][i].out;
		and[50][i].b <== lt[21][i].out;
		and[51][i] = AND();
		and[51][i].a <== states[i][25];
		and[51][i].b <== and[50][i].out;
		and[52][i] = AND();
		and[52][i].a <== states[i][26];
		and[52][i].b <== and[32][i].out;
		eq[53][i] = IsEqual();
		eq[53][i].in[0] <== in[i];
		eq[53][i].in[1] <== 128;
		eq[54][i] = IsEqual();
		eq[54][i].in[0] <== in[i];
		eq[54][i].in[1] <== 129;
		eq[55][i] = IsEqual();
		eq[55][i].in[0] <== in[i];
		eq[55][i].in[1] <== 130;
		eq[56][i] = IsEqual();
		eq[56][i].in[0] <== in[i];
		eq[56][i].in[1] <== 131;
		eq[57][i] = IsEqual();
		eq[57][i].in[0] <== in[i];
		eq[57][i].in[1] <== 132;
		eq[58][i] = IsEqual();
		eq[58][i].in[0] <== in[i];
		eq[58][i].in[1] <== 133;
		eq[59][i] = IsEqual();
		eq[59][i].in[0] <== in[i];
		eq[59][i].in[1] <== 134;
		eq[60][i] = IsEqual();
		eq[60][i].in[0] <== in[i];
		eq[60][i].in[1] <== 135;
		eq[61][i] = IsEqual();
		eq[61][i].in[0] <== in[i];
		eq[61][i].in[1] <== 136;
		eq[62][i] = IsEqual();
		eq[62][i].in[0] <== in[i];
		eq[62][i].in[1] <== 137;
		eq[63][i] = IsEqual();
		eq[63][i].in[0] <== in[i];
		eq[63][i].in[1] <== 138;
		eq[64][i] = IsEqual();
		eq[64][i].in[0] <== in[i];
		eq[64][i].in[1] <== 139;
		eq[65][i] = IsEqual();
		eq[65][i].in[0] <== in[i];
		eq[65][i].in[1] <== 140;
		eq[66][i] = IsEqual();
		eq[66][i].in[0] <== in[i];
		eq[66][i].in[1] <== 141;
		eq[67][i] = IsEqual();
		eq[67][i].in[0] <== in[i];
		eq[67][i].in[1] <== 142;
		eq[68][i] = IsEqual();
		eq[68][i].in[0] <== in[i];
		eq[68][i].in[1] <== 143;
		and[53][i] = AND();
		and[53][i].a <== states[i][27];
		multi_or[10][i] = MultiOR(16);
		multi_or[10][i].in[0] <== eq[53][i].out;
		multi_or[10][i].in[1] <== eq[54][i].out;
		multi_or[10][i].in[2] <== eq[55][i].out;
		multi_or[10][i].in[3] <== eq[56][i].out;
		multi_or[10][i].in[4] <== eq[57][i].out;
		multi_or[10][i].in[5] <== eq[58][i].out;
		multi_or[10][i].in[6] <== eq[59][i].out;
		multi_or[10][i].in[7] <== eq[60][i].out;
		multi_or[10][i].in[8] <== eq[61][i].out;
		multi_or[10][i].in[9] <== eq[62][i].out;
		multi_or[10][i].in[10] <== eq[63][i].out;
		multi_or[10][i].in[11] <== eq[64][i].out;
		multi_or[10][i].in[12] <== eq[65][i].out;
		multi_or[10][i].in[13] <== eq[66][i].out;
		multi_or[10][i].in[14] <== eq[67][i].out;
		multi_or[10][i].in[15] <== eq[68][i].out;
		and[53][i].b <== multi_or[10][i].out;
		and[54][i] = AND();
		and[54][i].a <== states[i][32];
		and[54][i].b <== multi_or[9][i].out;
		multi_or[11][i] = MultiOR(6);
		multi_or[11][i].in[0] <== and[48][i].out;
		multi_or[11][i].in[1] <== and[49][i].out;
		multi_or[11][i].in[2] <== and[51][i].out;
		multi_or[11][i].in[3] <== and[52][i].out;
		multi_or[11][i].in[4] <== and[53][i].out;
		multi_or[11][i].in[5] <== and[54][i].out;
		states[i+1][23] <== multi_or[11][i].out;
		eq[69][i] = IsEqual();
		eq[69][i].in[0] <== in[i];
		eq[69][i].in[1] <== 237;
		and[55][i] = AND();
		and[55][i].a <== states[i][19];
		and[55][i].b <== eq[69][i].out;
		and[56][i] = AND();
		and[56][i].a <== states[i][20];
		and[56][i].b <== eq[69][i].out;
		and[57][i] = AND();
		and[57][i].a <== states[i][32];
		and[57][i].b <== eq[69][i].out;
		multi_or[12][i] = MultiOR(3);
		multi_or[12][i].in[0] <== and[55][i].out;
		multi_or[12][i].in[1] <== and[56][i].out;
		multi_or[12][i].in[2] <== and[57][i].out;
		states[i+1][24] <== multi_or[12][i].out;
		eq[70][i] = IsEqual();
		eq[70][i].in[0] <== in[i];
		eq[70][i].in[1] <== 240;
		and[58][i] = AND();
		and[58][i].a <== states[i][19];
		and[58][i].b <== eq[70][i].out;
		and[59][i] = AND();
		and[59][i].a <== states[i][20];
		and[59][i].b <== eq[70][i].out;
		and[60][i] = AND();
		and[60][i].a <== states[i][32];
		and[60][i].b <== eq[70][i].out;
		multi_or[13][i] = MultiOR(3);
		multi_or[13][i].in[0] <== and[58][i].out;
		multi_or[13][i].in[1] <== and[59][i].out;
		multi_or[13][i].in[2] <== and[60][i].out;
		states[i+1][25] <== multi_or[13][i].out;
		eq[71][i] = IsEqual();
		eq[71][i].in[0] <== in[i];
		eq[71][i].in[1] <== 241;
		eq[72][i] = IsEqual();
		eq[72][i].in[0] <== in[i];
		eq[72][i].in[1] <== 242;
		eq[73][i] = IsEqual();
		eq[73][i].in[0] <== in[i];
		eq[73][i].in[1] <== 243;
		and[61][i] = AND();
		and[61][i].a <== states[i][19];
		multi_or[14][i] = MultiOR(3);
		multi_or[14][i].in[0] <== eq[71][i].out;
		multi_or[14][i].in[1] <== eq[72][i].out;
		multi_or[14][i].in[2] <== eq[73][i].out;
		and[61][i].b <== multi_or[14][i].out;
		and[62][i] = AND();
		and[62][i].a <== states[i][20];
		and[62][i].b <== multi_or[14][i].out;
		and[63][i] = AND();
		and[63][i].a <== states[i][32];
		and[63][i].b <== multi_or[14][i].out;
		multi_or[15][i] = MultiOR(3);
		multi_or[15][i].in[0] <== and[61][i].out;
		multi_or[15][i].in[1] <== and[62][i].out;
		multi_or[15][i].in[2] <== and[63][i].out;
		states[i+1][26] <== multi_or[15][i].out;
		eq[74][i] = IsEqual();
		eq[74][i].in[0] <== in[i];
		eq[74][i].in[1] <== 244;
		and[64][i] = AND();
		and[64][i].a <== states[i][19];
		and[64][i].b <== eq[74][i].out;
		and[65][i] = AND();
		and[65][i].a <== states[i][20];
		and[65][i].b <== eq[74][i].out;
		and[66][i] = AND();
		and[66][i].a <== states[i][32];
		and[66][i].b <== eq[74][i].out;
		multi_or[16][i] = MultiOR(3);
		multi_or[16][i].in[0] <== and[64][i].out;
		multi_or[16][i].in[1] <== and[65][i].out;
		multi_or[16][i].in[2] <== and[66][i].out;
		states[i+1][27] <== multi_or[16][i].out;
		eq[75][i] = IsEqual();
		eq[75][i].in[0] <== in[i];
		eq[75][i].in[1] <== 59;
		and[67][i] = AND();
		and[67][i].a <== states[i][20];
		and[67][i].b <== eq[75][i].out;
		states[i+1][28] <== and[67][i].out;
		eq[76][i] = IsEqual();
		eq[76][i].in[0] <== in[i];
		eq[76][i].in[1] <== 32;
		and[68][i] = AND();
		and[68][i].a <== states[i][28];
		and[68][i].b <== eq[76][i].out;
		states[i+1][29] <== and[68][i].out;
		and[69][i] = AND();
		and[69][i].a <== states[i][29];
		and[69][i].b <== eq[17][i].out;
		states[i+1][30] <== and[69][i].out;
		eq[77][i] = IsEqual();
		eq[77][i].in[0] <== in[i];
		eq[77][i].in[1] <== 104;
		and[70][i] = AND();
		and[70][i].a <== states[i][30];
		and[70][i].b <== eq[77][i].out;
		states[i+1][31] <== and[70][i].out;
		and[71][i] = AND();
		and[71][i].a <== states[i][31];
		and[71][i].b <== eq[20][i].out;
		states[i+1][32] <== and[71][i].out;
		lt[22][i] = LessEqThan(8);
		lt[22][i].in[0] <== 65;
		lt[22][i].in[1] <== in[i];
		lt[23][i] = LessEqThan(8);
		lt[23][i].in[0] <== in[i];
		lt[23][i].in[1] <== 90;
		and[72][i] = AND();
		and[72][i].a <== lt[22][i].out;
		and[72][i].b <== lt[23][i].out;
		eq[78][i] = IsEqual();
		eq[78][i].in[0] <== in[i];
		eq[78][i].in[1] <== 43;
		eq[79][i] = IsEqual();
		eq[79][i].in[0] <== in[i];
		eq[79][i].in[1] <== 47;
		eq[80][i] = IsEqual();
		eq[80][i].in[0] <== in[i];
		eq[80][i].in[1] <== 48;
		eq[81][i] = IsEqual();
		eq[81][i].in[0] <== in[i];
		eq[81][i].in[1] <== 49;
		eq[82][i] = IsEqual();
		eq[82][i].in[0] <== in[i];
		eq[82][i].in[1] <== 50;
		eq[83][i] = IsEqual();
		eq[83][i].in[0] <== in[i];
		eq[83][i].in[1] <== 51;
		eq[84][i] = IsEqual();
		eq[84][i].in[0] <== in[i];
		eq[84][i].in[1] <== 52;
		eq[85][i] = IsEqual();
		eq[85][i].in[0] <== in[i];
		eq[85][i].in[1] <== 53;
		eq[86][i] = IsEqual();
		eq[86][i].in[0] <== in[i];
		eq[86][i].in[1] <== 54;
		eq[87][i] = IsEqual();
		eq[87][i].in[0] <== in[i];
		eq[87][i].in[1] <== 55;
		eq[88][i] = IsEqual();
		eq[88][i].in[0] <== in[i];
		eq[88][i].in[1] <== 56;
		eq[89][i] = IsEqual();
		eq[89][i].in[0] <== in[i];
		eq[89][i].in[1] <== 57;
		and[73][i] = AND();
		and[73][i].a <== states[i][32];
		multi_or[17][i] = MultiOR(15);
		multi_or[17][i].in[0] <== and[72][i].out;
		multi_or[17][i].in[1] <== and[18][i].out;
		multi_or[17][i].in[2] <== eq[78][i].out;
		multi_or[17][i].in[3] <== eq[79][i].out;
		multi_or[17][i].in[4] <== eq[80][i].out;
		multi_or[17][i].in[5] <== eq[81][i].out;
		multi_or[17][i].in[6] <== eq[82][i].out;
		multi_or[17][i].in[7] <== eq[83][i].out;
		multi_or[17][i].in[8] <== eq[84][i].out;
		multi_or[17][i].in[9] <== eq[85][i].out;
		multi_or[17][i].in[10] <== eq[86][i].out;
		multi_or[17][i].in[11] <== eq[87][i].out;
		multi_or[17][i].in[12] <== eq[88][i].out;
		multi_or[17][i].in[13] <== eq[89][i].out;
		multi_or[17][i].in[14] <== eq[20][i].out;
		and[73][i].b <== multi_or[17][i].out;
		and[74][i] = AND();
		and[74][i].a <== states[i][33];
		and[74][i].b <== multi_or[17][i].out;
		multi_or[18][i] = MultiOR(2);
		multi_or[18][i].in[0] <== and[73][i].out;
		multi_or[18][i].in[1] <== and[74][i].out;
		states[i+1][33] <== multi_or[18][i].out;
		and[75][i] = AND();
		and[75][i].a <== states[i][33];
		and[75][i].b <== eq[75][i].out;
		states[i+1][34] <== and[75][i].out;
		from_zero_enabled[i] <== MultiNOR(34)([states_tmp[i+1][1], states_tmp[i+1][2], states[i+1][3], states[i+1][4], states[i+1][5], states[i+1][6], states[i+1][7], states[i+1][8], states[i+1][9], states[i+1][10], states[i+1][11], states[i+1][12], states[i+1][13], states[i+1][14], states[i+1][15], states[i+1][16], states[i+1][17], states[i+1][18], states[i+1][19], states[i+1][20], states[i+1][21], states[i+1][22], states[i+1][23], states[i+1][24], states[i+1][25], states[i+1][26], states[i+1][27], states[i+1][28], states[i+1][29], states[i+1][30], states[i+1][31], states[i+1][32], states[i+1][33], states[i+1][34]]);
		states[i+1][1] <== MultiOR(2)([states_tmp[i+1][1], from_zero_enabled[i] * and[0][i].out]);
		states[i+1][2] <== MultiOR(2)([states_tmp[i+1][2], from_zero_enabled[i] * and[1][i].out]);
		state_changed[i].in[0] <== states[i+1][1];
		state_changed[i].in[1] <== states[i+1][2];
		state_changed[i].in[2] <== states[i+1][3];
		state_changed[i].in[3] <== states[i+1][4];
		state_changed[i].in[4] <== states[i+1][5];
		state_changed[i].in[5] <== states[i+1][6];
		state_changed[i].in[6] <== states[i+1][7];
		state_changed[i].in[7] <== states[i+1][8];
		state_changed[i].in[8] <== states[i+1][9];
		state_changed[i].in[9] <== states[i+1][10];
		state_changed[i].in[10] <== states[i+1][11];
		state_changed[i].in[11] <== states[i+1][12];
		state_changed[i].in[12] <== states[i+1][13];
		state_changed[i].in[13] <== states[i+1][14];
		state_changed[i].in[14] <== states[i+1][15];
		state_changed[i].in[15] <== states[i+1][16];
		state_changed[i].in[16] <== states[i+1][17];
		state_changed[i].in[17] <== states[i+1][18];
		state_changed[i].in[18] <== states[i+1][19];
		state_changed[i].in[19] <== states[i+1][20];
		state_changed[i].in[20] <== states[i+1][21];
		state_changed[i].in[21] <== states[i+1][22];
		state_changed[i].in[22] <== states[i+1][23];
		state_changed[i].in[23] <== states[i+1][24];
		state_changed[i].in[24] <== states[i+1][25];
		state_changed[i].in[25] <== states[i+1][26];
		state_changed[i].in[26] <== states[i+1][27];
		state_changed[i].in[27] <== states[i+1][28];
		state_changed[i].in[28] <== states[i+1][29];
		state_changed[i].in[29] <== states[i+1][30];
		state_changed[i].in[30] <== states[i+1][31];
		state_changed[i].in[31] <== states[i+1][32];
		state_changed[i].in[32] <== states[i+1][33];
		state_changed[i].in[33] <== states[i+1][34];
	}

	component is_accepted = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		is_accepted.in[i] <== states[i][34];
	}
	out <== is_accepted.out;
	signal is_consecutive[msg_bytes+1][3];
	is_consecutive[msg_bytes][2] <== 0;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][34] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
		is_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][34], is_consecutive[msg_bytes-1-i][1]]);
	}
	// substrings calculated: [{(32, 33), (33, 33)}]
	signal prev_states0[2][msg_bytes];
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(32, 33), (33, 33)]
		prev_states0[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][32];
		prev_states0[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][33];
		is_substr0[i] <== MultiOR(2)([prev_states0[0][i] * states[i+2][33], prev_states0[1][i] * states[i+2][33]]);
		is_reveal0[i] <== MultiAND(3)([out, is_substr0[i], is_consecutive[i][2]]);
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
}