pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: ((\r\n)|^)subject:[^\r\n]+\r\n
template SubjectAllRegex(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		in[i+1] <== msg[i];
	}

	component eq[59][num_bytes];
	component lt[12][num_bytes];
	component and[42][num_bytes];
	component multi_or[15][num_bytes];
	signal states[num_bytes+1][21];
	component state_changed[num_bytes];

	states[0][0] <== 1;
	for (var i = 1; i < 21; i++) {
		states[0][i] <== 0;
	}

	for (var i = 0; i < num_bytes; i++) {
		state_changed[i] = MultiOR(20);
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 115;
		and[0][i] = AND();
		and[0][i].a <== states[i][4];
		and[0][i].b <== eq[0][i].out;
		and[1][i] = AND();
		and[1][i].a <== states[i][0];
		and[1][i].b <== eq[0][i].out;
		multi_or[0][i] = MultiOR(2);
		multi_or[0][i].in[0] <== and[0][i].out;
		multi_or[0][i].in[1] <== and[1][i].out;
		states[i+1][1] <== multi_or[0][i].out;
		state_changed[i].in[0] <== states[i+1][1];
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 13;
		and[2][i] = AND();
		and[2][i].a <== states[i][0];
		and[2][i].b <== eq[1][i].out;
		states[i+1][2] <== and[2][i].out;
		state_changed[i].in[1] <== states[i+1][2];
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 117;
		and[3][i] = AND();
		and[3][i].a <== states[i][1];
		and[3][i].b <== eq[2][i].out;
		states[i+1][3] <== and[3][i].out;
		state_changed[i].in[2] <== states[i+1][3];
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 10;
		and[4][i] = AND();
		and[4][i].a <== states[i][2];
		and[4][i].b <== eq[3][i].out;
		states[i+1][4] <== and[4][i].out;
		state_changed[i].in[3] <== states[i+1][4];
		eq[4][i] = IsEqual();
		eq[4][i].in[0] <== in[i];
		eq[4][i].in[1] <== 98;
		and[5][i] = AND();
		and[5][i].a <== states[i][3];
		and[5][i].b <== eq[4][i].out;
		states[i+1][5] <== and[5][i].out;
		state_changed[i].in[4] <== states[i+1][5];
		eq[5][i] = IsEqual();
		eq[5][i].in[0] <== in[i];
		eq[5][i].in[1] <== 106;
		and[6][i] = AND();
		and[6][i].a <== states[i][5];
		and[6][i].b <== eq[5][i].out;
		states[i+1][6] <== and[6][i].out;
		state_changed[i].in[5] <== states[i+1][6];
		eq[6][i] = IsEqual();
		eq[6][i].in[0] <== in[i];
		eq[6][i].in[1] <== 101;
		and[7][i] = AND();
		and[7][i].a <== states[i][6];
		and[7][i].b <== eq[6][i].out;
		states[i+1][7] <== and[7][i].out;
		state_changed[i].in[6] <== states[i+1][7];
		eq[7][i] = IsEqual();
		eq[7][i].in[0] <== in[i];
		eq[7][i].in[1] <== 99;
		and[8][i] = AND();
		and[8][i].a <== states[i][7];
		and[8][i].b <== eq[7][i].out;
		states[i+1][8] <== and[8][i].out;
		state_changed[i].in[7] <== states[i+1][8];
		eq[8][i] = IsEqual();
		eq[8][i].in[0] <== in[i];
		eq[8][i].in[1] <== 116;
		and[9][i] = AND();
		and[9][i].a <== states[i][8];
		and[9][i].b <== eq[8][i].out;
		states[i+1][9] <== and[9][i].out;
		state_changed[i].in[8] <== states[i+1][9];
		eq[9][i] = IsEqual();
		eq[9][i].in[0] <== in[i];
		eq[9][i].in[1] <== 58;
		and[10][i] = AND();
		and[10][i].a <== states[i][9];
		and[10][i].b <== eq[9][i].out;
		states[i+1][10] <== and[10][i].out;
		state_changed[i].in[9] <== states[i+1][10];
		lt[0][i] = LessEqThan(8);
		lt[0][i].in[0] <== 14;
		lt[0][i].in[1] <== in[i];
		lt[1][i] = LessEqThan(8);
		lt[1][i].in[0] <== in[i];
		lt[1][i].in[1] <== 127;
		and[11][i] = AND();
		and[11][i].a <== lt[0][i].out;
		and[11][i].b <== lt[1][i].out;
		eq[10][i] = IsEqual();
		eq[10][i].in[0] <== in[i];
		eq[10][i].in[1] <== 6;
		eq[11][i] = IsEqual();
		eq[11][i].in[0] <== in[i];
		eq[11][i].in[1] <== 5;
		eq[12][i] = IsEqual();
		eq[12][i].in[0] <== in[i];
		eq[12][i].in[1] <== 12;
		eq[13][i] = IsEqual();
		eq[13][i].in[0] <== in[i];
		eq[13][i].in[1] <== 0;
		eq[14][i] = IsEqual();
		eq[14][i].in[0] <== in[i];
		eq[14][i].in[1] <== 4;
		eq[15][i] = IsEqual();
		eq[15][i].in[0] <== in[i];
		eq[15][i].in[1] <== 3;
		eq[16][i] = IsEqual();
		eq[16][i].in[0] <== in[i];
		eq[16][i].in[1] <== 2;
		eq[17][i] = IsEqual();
		eq[17][i].in[0] <== in[i];
		eq[17][i].in[1] <== 8;
		eq[18][i] = IsEqual();
		eq[18][i].in[0] <== in[i];
		eq[18][i].in[1] <== 7;
		eq[19][i] = IsEqual();
		eq[19][i].in[0] <== in[i];
		eq[19][i].in[1] <== 9;
		eq[20][i] = IsEqual();
		eq[20][i].in[0] <== in[i];
		eq[20][i].in[1] <== 11;
		eq[21][i] = IsEqual();
		eq[21][i].in[0] <== in[i];
		eq[21][i].in[1] <== 1;
		and[12][i] = AND();
		and[12][i].a <== states[i][10];
		multi_or[1][i] = MultiOR(13);
		multi_or[1][i].in[0] <== and[11][i].out;
		multi_or[1][i].in[1] <== eq[10][i].out;
		multi_or[1][i].in[2] <== eq[11][i].out;
		multi_or[1][i].in[3] <== eq[12][i].out;
		multi_or[1][i].in[4] <== eq[13][i].out;
		multi_or[1][i].in[5] <== eq[14][i].out;
		multi_or[1][i].in[6] <== eq[15][i].out;
		multi_or[1][i].in[7] <== eq[16][i].out;
		multi_or[1][i].in[8] <== eq[17][i].out;
		multi_or[1][i].in[9] <== eq[18][i].out;
		multi_or[1][i].in[10] <== eq[19][i].out;
		multi_or[1][i].in[11] <== eq[20][i].out;
		multi_or[1][i].in[12] <== eq[21][i].out;
		and[12][i].b <== multi_or[1][i].out;
		lt[2][i] = LessEqThan(8);
		lt[2][i].in[0] <== 128;
		lt[2][i].in[1] <== in[i];
		lt[3][i] = LessEqThan(8);
		lt[3][i].in[0] <== in[i];
		lt[3][i].in[1] <== 191;
		and[13][i] = AND();
		and[13][i].a <== lt[2][i].out;
		and[13][i].b <== lt[3][i].out;
		and[14][i] = AND();
		and[14][i].a <== states[i][12];
		and[14][i].b <== and[13][i].out;
		and[15][i] = AND();
		and[15][i].a <== states[i][11];
		multi_or[2][i] = MultiOR(13);
		multi_or[2][i].in[0] <== and[11][i].out;
		multi_or[2][i].in[1] <== eq[17][i].out;
		multi_or[2][i].in[2] <== eq[10][i].out;
		multi_or[2][i].in[3] <== eq[14][i].out;
		multi_or[2][i].in[4] <== eq[20][i].out;
		multi_or[2][i].in[5] <== eq[21][i].out;
		multi_or[2][i].in[6] <== eq[16][i].out;
		multi_or[2][i].in[7] <== eq[13][i].out;
		multi_or[2][i].in[8] <== eq[19][i].out;
		multi_or[2][i].in[9] <== eq[12][i].out;
		multi_or[2][i].in[10] <== eq[11][i].out;
		multi_or[2][i].in[11] <== eq[15][i].out;
		multi_or[2][i].in[12] <== eq[18][i].out;
		and[15][i].b <== multi_or[2][i].out;
		multi_or[3][i] = MultiOR(3);
		multi_or[3][i].in[0] <== and[12][i].out;
		multi_or[3][i].in[1] <== and[14][i].out;
		multi_or[3][i].in[2] <== and[15][i].out;
		states[i+1][11] <== multi_or[3][i].out;
		state_changed[i].in[10] <== states[i+1][11];
		lt[4][i] = LessEqThan(8);
		lt[4][i].in[0] <== 194;
		lt[4][i].in[1] <== in[i];
		lt[5][i] = LessEqThan(8);
		lt[5][i].in[0] <== in[i];
		lt[5][i].in[1] <== 223;
		and[16][i] = AND();
		and[16][i].a <== lt[4][i].out;
		and[16][i].b <== lt[5][i].out;
		and[17][i] = AND();
		and[17][i].a <== states[i][11];
		and[17][i].b <== and[16][i].out;
		lt[6][i] = LessEqThan(8);
		lt[6][i].in[0] <== 160;
		lt[6][i].in[1] <== in[i];
		lt[7][i] = LessEqThan(8);
		lt[7][i].in[0] <== in[i];
		lt[7][i].in[1] <== 191;
		and[18][i] = AND();
		and[18][i].a <== lt[6][i].out;
		and[18][i].b <== lt[7][i].out;
		and[19][i] = AND();
		and[19][i].a <== states[i][13];
		and[19][i].b <== and[18][i].out;
		lt[8][i] = LessEqThan(8);
		lt[8][i].in[0] <== 128;
		lt[8][i].in[1] <== in[i];
		lt[9][i] = LessEqThan(8);
		lt[9][i].in[0] <== in[i];
		lt[9][i].in[1] <== 159;
		and[20][i] = AND();
		and[20][i].a <== lt[8][i].out;
		and[20][i].b <== lt[9][i].out;
		and[21][i] = AND();
		and[21][i].a <== states[i][15];
		and[21][i].b <== and[20][i].out;
		and[22][i] = AND();
		and[22][i].a <== states[i][10];
		and[22][i].b <== and[16][i].out;
		and[23][i] = AND();
		and[23][i].a <== states[i][14];
		and[23][i].b <== and[13][i].out;
		multi_or[4][i] = MultiOR(5);
		multi_or[4][i].in[0] <== and[17][i].out;
		multi_or[4][i].in[1] <== and[19][i].out;
		multi_or[4][i].in[2] <== and[21][i].out;
		multi_or[4][i].in[3] <== and[22][i].out;
		multi_or[4][i].in[4] <== and[23][i].out;
		states[i+1][12] <== multi_or[4][i].out;
		state_changed[i].in[11] <== states[i+1][12];
		eq[22][i] = IsEqual();
		eq[22][i].in[0] <== in[i];
		eq[22][i].in[1] <== 224;
		and[24][i] = AND();
		and[24][i].a <== states[i][10];
		and[24][i].b <== eq[22][i].out;
		and[25][i] = AND();
		and[25][i].a <== states[i][11];
		and[25][i].b <== eq[22][i].out;
		multi_or[5][i] = MultiOR(2);
		multi_or[5][i].in[0] <== and[24][i].out;
		multi_or[5][i].in[1] <== and[25][i].out;
		states[i+1][13] <== multi_or[5][i].out;
		state_changed[i].in[12] <== states[i+1][13];
		lt[10][i] = LessEqThan(8);
		lt[10][i].in[0] <== 144;
		lt[10][i].in[1] <== in[i];
		lt[11][i] = LessEqThan(8);
		lt[11][i].in[0] <== in[i];
		lt[11][i].in[1] <== 191;
		and[26][i] = AND();
		and[26][i].a <== lt[10][i].out;
		and[26][i].b <== lt[11][i].out;
		and[27][i] = AND();
		and[27][i].a <== states[i][16];
		and[27][i].b <== and[26][i].out;
		eq[23][i] = IsEqual();
		eq[23][i].in[0] <== in[i];
		eq[23][i].in[1] <== 131;
		eq[24][i] = IsEqual();
		eq[24][i].in[0] <== in[i];
		eq[24][i].in[1] <== 139;
		eq[25][i] = IsEqual();
		eq[25][i].in[0] <== in[i];
		eq[25][i].in[1] <== 142;
		eq[26][i] = IsEqual();
		eq[26][i].in[0] <== in[i];
		eq[26][i].in[1] <== 130;
		eq[27][i] = IsEqual();
		eq[27][i].in[0] <== in[i];
		eq[27][i].in[1] <== 132;
		eq[28][i] = IsEqual();
		eq[28][i].in[0] <== in[i];
		eq[28][i].in[1] <== 134;
		eq[29][i] = IsEqual();
		eq[29][i].in[0] <== in[i];
		eq[29][i].in[1] <== 128;
		eq[30][i] = IsEqual();
		eq[30][i].in[0] <== in[i];
		eq[30][i].in[1] <== 136;
		eq[31][i] = IsEqual();
		eq[31][i].in[0] <== in[i];
		eq[31][i].in[1] <== 137;
		eq[32][i] = IsEqual();
		eq[32][i].in[0] <== in[i];
		eq[32][i].in[1] <== 129;
		eq[33][i] = IsEqual();
		eq[33][i].in[0] <== in[i];
		eq[33][i].in[1] <== 138;
		eq[34][i] = IsEqual();
		eq[34][i].in[0] <== in[i];
		eq[34][i].in[1] <== 141;
		eq[35][i] = IsEqual();
		eq[35][i].in[0] <== in[i];
		eq[35][i].in[1] <== 133;
		eq[36][i] = IsEqual();
		eq[36][i].in[0] <== in[i];
		eq[36][i].in[1] <== 140;
		eq[37][i] = IsEqual();
		eq[37][i].in[0] <== in[i];
		eq[37][i].in[1] <== 135;
		eq[38][i] = IsEqual();
		eq[38][i].in[0] <== in[i];
		eq[38][i].in[1] <== 143;
		and[28][i] = AND();
		and[28][i].a <== states[i][18];
		multi_or[6][i] = MultiOR(16);
		multi_or[6][i].in[0] <== eq[23][i].out;
		multi_or[6][i].in[1] <== eq[24][i].out;
		multi_or[6][i].in[2] <== eq[25][i].out;
		multi_or[6][i].in[3] <== eq[26][i].out;
		multi_or[6][i].in[4] <== eq[27][i].out;
		multi_or[6][i].in[5] <== eq[28][i].out;
		multi_or[6][i].in[6] <== eq[29][i].out;
		multi_or[6][i].in[7] <== eq[30][i].out;
		multi_or[6][i].in[8] <== eq[31][i].out;
		multi_or[6][i].in[9] <== eq[32][i].out;
		multi_or[6][i].in[10] <== eq[33][i].out;
		multi_or[6][i].in[11] <== eq[34][i].out;
		multi_or[6][i].in[12] <== eq[35][i].out;
		multi_or[6][i].in[13] <== eq[36][i].out;
		multi_or[6][i].in[14] <== eq[37][i].out;
		multi_or[6][i].in[15] <== eq[38][i].out;
		and[28][i].b <== multi_or[6][i].out;
		and[29][i] = AND();
		and[29][i].a <== states[i][17];
		and[29][i].b <== and[13][i].out;
		eq[39][i] = IsEqual();
		eq[39][i].in[0] <== in[i];
		eq[39][i].in[1] <== 232;
		eq[40][i] = IsEqual();
		eq[40][i].in[0] <== in[i];
		eq[40][i].in[1] <== 231;
		eq[41][i] = IsEqual();
		eq[41][i].in[0] <== in[i];
		eq[41][i].in[1] <== 233;
		eq[42][i] = IsEqual();
		eq[42][i].in[0] <== in[i];
		eq[42][i].in[1] <== 226;
		eq[43][i] = IsEqual();
		eq[43][i].in[0] <== in[i];
		eq[43][i].in[1] <== 235;
		eq[44][i] = IsEqual();
		eq[44][i].in[0] <== in[i];
		eq[44][i].in[1] <== 227;
		eq[45][i] = IsEqual();
		eq[45][i].in[0] <== in[i];
		eq[45][i].in[1] <== 225;
		eq[46][i] = IsEqual();
		eq[46][i].in[0] <== in[i];
		eq[46][i].in[1] <== 229;
		eq[47][i] = IsEqual();
		eq[47][i].in[0] <== in[i];
		eq[47][i].in[1] <== 230;
		eq[48][i] = IsEqual();
		eq[48][i].in[0] <== in[i];
		eq[48][i].in[1] <== 228;
		eq[49][i] = IsEqual();
		eq[49][i].in[0] <== in[i];
		eq[49][i].in[1] <== 234;
		eq[50][i] = IsEqual();
		eq[50][i].in[0] <== in[i];
		eq[50][i].in[1] <== 236;
		eq[51][i] = IsEqual();
		eq[51][i].in[0] <== in[i];
		eq[51][i].in[1] <== 238;
		eq[52][i] = IsEqual();
		eq[52][i].in[0] <== in[i];
		eq[52][i].in[1] <== 239;
		and[30][i] = AND();
		and[30][i].a <== states[i][11];
		multi_or[7][i] = MultiOR(14);
		multi_or[7][i].in[0] <== eq[39][i].out;
		multi_or[7][i].in[1] <== eq[40][i].out;
		multi_or[7][i].in[2] <== eq[41][i].out;
		multi_or[7][i].in[3] <== eq[42][i].out;
		multi_or[7][i].in[4] <== eq[43][i].out;
		multi_or[7][i].in[5] <== eq[44][i].out;
		multi_or[7][i].in[6] <== eq[45][i].out;
		multi_or[7][i].in[7] <== eq[46][i].out;
		multi_or[7][i].in[8] <== eq[47][i].out;
		multi_or[7][i].in[9] <== eq[48][i].out;
		multi_or[7][i].in[10] <== eq[49][i].out;
		multi_or[7][i].in[11] <== eq[50][i].out;
		multi_or[7][i].in[12] <== eq[51][i].out;
		multi_or[7][i].in[13] <== eq[52][i].out;
		and[30][i].b <== multi_or[7][i].out;
		and[31][i] = AND();
		and[31][i].a <== states[i][10];
		multi_or[8][i] = MultiOR(14);
		multi_or[8][i].in[0] <== eq[45][i].out;
		multi_or[8][i].in[1] <== eq[51][i].out;
		multi_or[8][i].in[2] <== eq[52][i].out;
		multi_or[8][i].in[3] <== eq[47][i].out;
		multi_or[8][i].in[4] <== eq[46][i].out;
		multi_or[8][i].in[5] <== eq[49][i].out;
		multi_or[8][i].in[6] <== eq[42][i].out;
		multi_or[8][i].in[7] <== eq[44][i].out;
		multi_or[8][i].in[8] <== eq[39][i].out;
		multi_or[8][i].in[9] <== eq[41][i].out;
		multi_or[8][i].in[10] <== eq[43][i].out;
		multi_or[8][i].in[11] <== eq[50][i].out;
		multi_or[8][i].in[12] <== eq[40][i].out;
		multi_or[8][i].in[13] <== eq[48][i].out;
		and[31][i].b <== multi_or[8][i].out;
		multi_or[9][i] = MultiOR(5);
		multi_or[9][i].in[0] <== and[27][i].out;
		multi_or[9][i].in[1] <== and[28][i].out;
		multi_or[9][i].in[2] <== and[29][i].out;
		multi_or[9][i].in[3] <== and[30][i].out;
		multi_or[9][i].in[4] <== and[31][i].out;
		states[i+1][14] <== multi_or[9][i].out;
		state_changed[i].in[13] <== states[i+1][14];
		eq[53][i] = IsEqual();
		eq[53][i].in[0] <== in[i];
		eq[53][i].in[1] <== 237;
		and[32][i] = AND();
		and[32][i].a <== states[i][10];
		and[32][i].b <== eq[53][i].out;
		and[33][i] = AND();
		and[33][i].a <== states[i][11];
		and[33][i].b <== eq[53][i].out;
		multi_or[10][i] = MultiOR(2);
		multi_or[10][i].in[0] <== and[32][i].out;
		multi_or[10][i].in[1] <== and[33][i].out;
		states[i+1][15] <== multi_or[10][i].out;
		state_changed[i].in[14] <== states[i+1][15];
		eq[54][i] = IsEqual();
		eq[54][i].in[0] <== in[i];
		eq[54][i].in[1] <== 240;
		and[34][i] = AND();
		and[34][i].a <== states[i][10];
		and[34][i].b <== eq[54][i].out;
		and[35][i] = AND();
		and[35][i].a <== states[i][11];
		and[35][i].b <== eq[54][i].out;
		multi_or[11][i] = MultiOR(2);
		multi_or[11][i].in[0] <== and[34][i].out;
		multi_or[11][i].in[1] <== and[35][i].out;
		states[i+1][16] <== multi_or[11][i].out;
		state_changed[i].in[15] <== states[i+1][16];
		eq[55][i] = IsEqual();
		eq[55][i].in[0] <== in[i];
		eq[55][i].in[1] <== 241;
		eq[56][i] = IsEqual();
		eq[56][i].in[0] <== in[i];
		eq[56][i].in[1] <== 242;
		eq[57][i] = IsEqual();
		eq[57][i].in[0] <== in[i];
		eq[57][i].in[1] <== 243;
		and[36][i] = AND();
		and[36][i].a <== states[i][10];
		multi_or[12][i] = MultiOR(3);
		multi_or[12][i].in[0] <== eq[55][i].out;
		multi_or[12][i].in[1] <== eq[56][i].out;
		multi_or[12][i].in[2] <== eq[57][i].out;
		and[36][i].b <== multi_or[12][i].out;
		and[37][i] = AND();
		and[37][i].a <== states[i][11];
		and[37][i].b <== multi_or[12][i].out;
		multi_or[13][i] = MultiOR(2);
		multi_or[13][i].in[0] <== and[36][i].out;
		multi_or[13][i].in[1] <== and[37][i].out;
		states[i+1][17] <== multi_or[13][i].out;
		state_changed[i].in[16] <== states[i+1][17];
		eq[58][i] = IsEqual();
		eq[58][i].in[0] <== in[i];
		eq[58][i].in[1] <== 244;
		and[38][i] = AND();
		and[38][i].a <== states[i][10];
		and[38][i].b <== eq[58][i].out;
		and[39][i] = AND();
		and[39][i].a <== states[i][11];
		and[39][i].b <== eq[58][i].out;
		multi_or[14][i] = MultiOR(2);
		multi_or[14][i].in[0] <== and[38][i].out;
		multi_or[14][i].in[1] <== and[39][i].out;
		states[i+1][18] <== multi_or[14][i].out;
		state_changed[i].in[17] <== states[i+1][18];
		and[40][i] = AND();
		and[40][i].a <== states[i][11];
		and[40][i].b <== eq[1][i].out;
		states[i+1][19] <== and[40][i].out;
		state_changed[i].in[18] <== states[i+1][19];
		and[41][i] = AND();
		and[41][i].a <== states[i][19];
		and[41][i].b <== eq[3][i].out;
		states[i+1][20] <== and[41][i].out;
		state_changed[i].in[19] <== states[i+1][20];
		states[i+1][0] <== 1 - state_changed[i].out;
	}

	component final_state_result = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		final_state_result.in[i] <== states[i][20];
	}
	out <== final_state_result.out;
	signal is_consecutive[msg_bytes+1][2];
	is_consecutive[msg_bytes][1] <== 1;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][20] * (1 - is_consecutive[msg_bytes-i][1]) + is_consecutive[msg_bytes-i][1];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
	}
	// substrings calculated: [{(10, 16), (11, 17), (12, 11), (11, 18), (14, 12), (10, 11), (10, 12), (11, 14), (10, 17), (10, 13), (16, 14), (18, 14), (10, 15), (15, 12), (10, 14), (11, 15), (11, 13), (11, 11), (11, 16), (11, 12), (17, 14), (10, 18), (13, 12)}]
	signal is_substr0[msg_bytes][24];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		is_substr0[i][0] <== 0;
		is_substr0[i][1] <== is_substr0[i][0] + states[i+1][10] * states[i+2][11];
		is_substr0[i][2] <== is_substr0[i][1] + states[i+1][10] * states[i+2][12];
		is_substr0[i][3] <== is_substr0[i][2] + states[i+1][10] * states[i+2][13];
		is_substr0[i][4] <== is_substr0[i][3] + states[i+1][10] * states[i+2][14];
		is_substr0[i][5] <== is_substr0[i][4] + states[i+1][10] * states[i+2][15];
		is_substr0[i][6] <== is_substr0[i][5] + states[i+1][10] * states[i+2][16];
		is_substr0[i][7] <== is_substr0[i][6] + states[i+1][10] * states[i+2][17];
		is_substr0[i][8] <== is_substr0[i][7] + states[i+1][10] * states[i+2][18];
		is_substr0[i][9] <== is_substr0[i][8] + states[i+1][11] * states[i+2][11];
		is_substr0[i][10] <== is_substr0[i][9] + states[i+1][11] * states[i+2][12];
		is_substr0[i][11] <== is_substr0[i][10] + states[i+1][11] * states[i+2][13];
		is_substr0[i][12] <== is_substr0[i][11] + states[i+1][11] * states[i+2][14];
		is_substr0[i][13] <== is_substr0[i][12] + states[i+1][11] * states[i+2][15];
		is_substr0[i][14] <== is_substr0[i][13] + states[i+1][11] * states[i+2][16];
		is_substr0[i][15] <== is_substr0[i][14] + states[i+1][11] * states[i+2][17];
		is_substr0[i][16] <== is_substr0[i][15] + states[i+1][11] * states[i+2][18];
		is_substr0[i][17] <== is_substr0[i][16] + states[i+1][12] * states[i+2][11];
		is_substr0[i][18] <== is_substr0[i][17] + states[i+1][13] * states[i+2][12];
		is_substr0[i][19] <== is_substr0[i][18] + states[i+1][14] * states[i+2][12];
		is_substr0[i][20] <== is_substr0[i][19] + states[i+1][15] * states[i+2][12];
		is_substr0[i][21] <== is_substr0[i][20] + states[i+1][16] * states[i+2][14];
		is_substr0[i][22] <== is_substr0[i][21] + states[i+1][17] * states[i+2][14];
		is_substr0[i][23] <== is_substr0[i][22] + states[i+1][18] * states[i+2][14];
		is_reveal0[i] <== is_substr0[i][23] * is_consecutive[i][1];
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
}