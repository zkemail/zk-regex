pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: Latin-Extension=[¡-ƿ]+ Greek=[Ͱ-Ͽ]+ Cyrillic=[Ѐ-ӿ]+ Arabic=[؀-ۿ]+ Devanagari=[ऀ-ॿ]+ Hiragana&Katakana=[ぁ-ヿ]+
template InternationalCharsDecomposed(msg_bytes) {
	signal input msg[msg_bytes];
	signal output out;

	var num_bytes = msg_bytes+1;
	signal in[num_bytes];
	in[0]<==255;
	for (var i = 0; i < msg_bytes; i++) {
		in[i+1] <== msg[i];
	}

	component eq[67][num_bytes];
	component lt[6][num_bytes];
	component and[103][num_bytes];
	component multi_or[18][num_bytes];
	signal states[num_bytes+1][90];
	signal states_tmp[num_bytes+1][90];
	signal from_zero_enabled[num_bytes+1];
	from_zero_enabled[num_bytes] <== 0;
	component state_changed[num_bytes];

	for (var i = 1; i < 90; i++) {
		states[0][i] <== 0;
	}

	for (var i = 0; i < num_bytes; i++) {
		state_changed[i] = MultiOR(89);
		states[i][0] <== 1;
		eq[0][i] = IsEqual();
		eq[0][i].in[0] <== in[i];
		eq[0][i].in[1] <== 76;
		and[0][i] = AND();
		and[0][i].a <== states[i][0];
		and[0][i].b <== eq[0][i].out;
		states_tmp[i+1][1] <== 0;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 97;
		and[1][i] = AND();
		and[1][i].a <== states[i][1];
		and[1][i].b <== eq[1][i].out;
		states[i+1][2] <== and[1][i].out;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 116;
		and[2][i] = AND();
		and[2][i].a <== states[i][2];
		and[2][i].b <== eq[2][i].out;
		states[i+1][3] <== and[2][i].out;
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 105;
		and[3][i] = AND();
		and[3][i].a <== states[i][3];
		and[3][i].b <== eq[3][i].out;
		states[i+1][4] <== and[3][i].out;
		eq[4][i] = IsEqual();
		eq[4][i].in[0] <== in[i];
		eq[4][i].in[1] <== 110;
		and[4][i] = AND();
		and[4][i].a <== states[i][4];
		and[4][i].b <== eq[4][i].out;
		states[i+1][5] <== and[4][i].out;
		eq[5][i] = IsEqual();
		eq[5][i].in[0] <== in[i];
		eq[5][i].in[1] <== 45;
		and[5][i] = AND();
		and[5][i].a <== states[i][5];
		and[5][i].b <== eq[5][i].out;
		states[i+1][6] <== and[5][i].out;
		eq[6][i] = IsEqual();
		eq[6][i].in[0] <== in[i];
		eq[6][i].in[1] <== 69;
		and[6][i] = AND();
		and[6][i].a <== states[i][6];
		and[6][i].b <== eq[6][i].out;
		states[i+1][7] <== and[6][i].out;
		eq[7][i] = IsEqual();
		eq[7][i].in[0] <== in[i];
		eq[7][i].in[1] <== 120;
		and[7][i] = AND();
		and[7][i].a <== states[i][7];
		and[7][i].b <== eq[7][i].out;
		states[i+1][8] <== and[7][i].out;
		and[8][i] = AND();
		and[8][i].a <== states[i][8];
		and[8][i].b <== eq[2][i].out;
		states[i+1][9] <== and[8][i].out;
		eq[8][i] = IsEqual();
		eq[8][i].in[0] <== in[i];
		eq[8][i].in[1] <== 101;
		and[9][i] = AND();
		and[9][i].a <== states[i][9];
		and[9][i].b <== eq[8][i].out;
		states[i+1][10] <== and[9][i].out;
		and[10][i] = AND();
		and[10][i].a <== states[i][10];
		and[10][i].b <== eq[4][i].out;
		states[i+1][11] <== and[10][i].out;
		eq[9][i] = IsEqual();
		eq[9][i].in[0] <== in[i];
		eq[9][i].in[1] <== 115;
		and[11][i] = AND();
		and[11][i].a <== states[i][11];
		and[11][i].b <== eq[9][i].out;
		states[i+1][12] <== and[11][i].out;
		and[12][i] = AND();
		and[12][i].a <== states[i][12];
		and[12][i].b <== eq[3][i].out;
		states[i+1][13] <== and[12][i].out;
		eq[10][i] = IsEqual();
		eq[10][i].in[0] <== in[i];
		eq[10][i].in[1] <== 111;
		and[13][i] = AND();
		and[13][i].a <== states[i][13];
		and[13][i].b <== eq[10][i].out;
		states[i+1][14] <== and[13][i].out;
		and[14][i] = AND();
		and[14][i].a <== states[i][14];
		and[14][i].b <== eq[4][i].out;
		states[i+1][15] <== and[14][i].out;
		eq[11][i] = IsEqual();
		eq[11][i].in[0] <== in[i];
		eq[11][i].in[1] <== 61;
		and[15][i] = AND();
		and[15][i].a <== states[i][15];
		and[15][i].b <== eq[11][i].out;
		states[i+1][16] <== and[15][i].out;
		eq[12][i] = IsEqual();
		eq[12][i].in[0] <== in[i];
		eq[12][i].in[1] <== 195;
		eq[13][i] = IsEqual();
		eq[13][i].in[0] <== in[i];
		eq[13][i].in[1] <== 196;
		eq[14][i] = IsEqual();
		eq[14][i].in[0] <== in[i];
		eq[14][i].in[1] <== 197;
		eq[15][i] = IsEqual();
		eq[15][i].in[0] <== in[i];
		eq[15][i].in[1] <== 198;
		and[16][i] = AND();
		and[16][i].a <== states[i][16];
		multi_or[0][i] = MultiOR(4);
		multi_or[0][i].in[0] <== eq[12][i].out;
		multi_or[0][i].in[1] <== eq[13][i].out;
		multi_or[0][i].in[2] <== eq[14][i].out;
		multi_or[0][i].in[3] <== eq[15][i].out;
		and[16][i].b <== multi_or[0][i].out;
		and[17][i] = AND();
		and[17][i].a <== states[i][19];
		and[17][i].b <== multi_or[0][i].out;
		multi_or[1][i] = MultiOR(2);
		multi_or[1][i].in[0] <== and[16][i].out;
		multi_or[1][i].in[1] <== and[17][i].out;
		states[i+1][17] <== multi_or[1][i].out;
		eq[16][i] = IsEqual();
		eq[16][i].in[0] <== in[i];
		eq[16][i].in[1] <== 194;
		and[18][i] = AND();
		and[18][i].a <== states[i][16];
		and[18][i].b <== eq[16][i].out;
		and[19][i] = AND();
		and[19][i].a <== states[i][19];
		and[19][i].b <== eq[16][i].out;
		multi_or[2][i] = MultiOR(2);
		multi_or[2][i].in[0] <== and[18][i].out;
		multi_or[2][i].in[1] <== and[19][i].out;
		states[i+1][18] <== multi_or[2][i].out;
		lt[0][i] = LessEqThan(8);
		lt[0][i].in[0] <== 128;
		lt[0][i].in[1] <== in[i];
		lt[1][i] = LessEqThan(8);
		lt[1][i].in[0] <== in[i];
		lt[1][i].in[1] <== 191;
		and[20][i] = AND();
		and[20][i].a <== lt[0][i].out;
		and[20][i].b <== lt[1][i].out;
		and[21][i] = AND();
		and[21][i].a <== states[i][17];
		and[21][i].b <== and[20][i].out;
		lt[2][i] = LessEqThan(8);
		lt[2][i].in[0] <== 161;
		lt[2][i].in[1] <== in[i];
		lt[3][i] = LessEqThan(8);
		lt[3][i].in[0] <== in[i];
		lt[3][i].in[1] <== 191;
		and[22][i] = AND();
		and[22][i].a <== lt[2][i].out;
		and[22][i].b <== lt[3][i].out;
		and[23][i] = AND();
		and[23][i].a <== states[i][18];
		and[23][i].b <== and[22][i].out;
		multi_or[3][i] = MultiOR(2);
		multi_or[3][i].in[0] <== and[21][i].out;
		multi_or[3][i].in[1] <== and[23][i].out;
		states[i+1][19] <== multi_or[3][i].out;
		eq[17][i] = IsEqual();
		eq[17][i].in[0] <== in[i];
		eq[17][i].in[1] <== 32;
		and[24][i] = AND();
		and[24][i].a <== states[i][19];
		and[24][i].b <== eq[17][i].out;
		states[i+1][20] <== and[24][i].out;
		eq[18][i] = IsEqual();
		eq[18][i].in[0] <== in[i];
		eq[18][i].in[1] <== 71;
		and[25][i] = AND();
		and[25][i].a <== states[i][20];
		and[25][i].b <== eq[18][i].out;
		states[i+1][21] <== and[25][i].out;
		eq[19][i] = IsEqual();
		eq[19][i].in[0] <== in[i];
		eq[19][i].in[1] <== 114;
		and[26][i] = AND();
		and[26][i].a <== states[i][21];
		and[26][i].b <== eq[19][i].out;
		states[i+1][22] <== and[26][i].out;
		and[27][i] = AND();
		and[27][i].a <== states[i][22];
		and[27][i].b <== eq[8][i].out;
		states[i+1][23] <== and[27][i].out;
		and[28][i] = AND();
		and[28][i].a <== states[i][23];
		and[28][i].b <== eq[8][i].out;
		states[i+1][24] <== and[28][i].out;
		eq[20][i] = IsEqual();
		eq[20][i].in[0] <== in[i];
		eq[20][i].in[1] <== 107;
		and[29][i] = AND();
		and[29][i].a <== states[i][24];
		and[29][i].b <== eq[20][i].out;
		states[i+1][25] <== and[29][i].out;
		and[30][i] = AND();
		and[30][i].a <== states[i][25];
		and[30][i].b <== eq[11][i].out;
		states[i+1][26] <== and[30][i].out;
		eq[21][i] = IsEqual();
		eq[21][i].in[0] <== in[i];
		eq[21][i].in[1] <== 206;
		eq[22][i] = IsEqual();
		eq[22][i].in[0] <== in[i];
		eq[22][i].in[1] <== 207;
		and[31][i] = AND();
		and[31][i].a <== states[i][26];
		multi_or[4][i] = MultiOR(2);
		multi_or[4][i].in[0] <== eq[21][i].out;
		multi_or[4][i].in[1] <== eq[22][i].out;
		and[31][i].b <== multi_or[4][i].out;
		and[32][i] = AND();
		and[32][i].a <== states[i][29];
		and[32][i].b <== multi_or[4][i].out;
		multi_or[5][i] = MultiOR(2);
		multi_or[5][i].in[0] <== and[31][i].out;
		multi_or[5][i].in[1] <== and[32][i].out;
		states[i+1][27] <== multi_or[5][i].out;
		eq[23][i] = IsEqual();
		eq[23][i].in[0] <== in[i];
		eq[23][i].in[1] <== 205;
		and[33][i] = AND();
		and[33][i].a <== states[i][26];
		and[33][i].b <== eq[23][i].out;
		and[34][i] = AND();
		and[34][i].a <== states[i][29];
		and[34][i].b <== eq[23][i].out;
		multi_or[6][i] = MultiOR(2);
		multi_or[6][i].in[0] <== and[33][i].out;
		multi_or[6][i].in[1] <== and[34][i].out;
		states[i+1][28] <== multi_or[6][i].out;
		and[35][i] = AND();
		and[35][i].a <== states[i][27];
		and[35][i].b <== and[20][i].out;
		eq[24][i] = IsEqual();
		eq[24][i].in[0] <== in[i];
		eq[24][i].in[1] <== 176;
		eq[25][i] = IsEqual();
		eq[25][i].in[0] <== in[i];
		eq[25][i].in[1] <== 177;
		eq[26][i] = IsEqual();
		eq[26][i].in[0] <== in[i];
		eq[26][i].in[1] <== 178;
		eq[27][i] = IsEqual();
		eq[27][i].in[0] <== in[i];
		eq[27][i].in[1] <== 179;
		eq[28][i] = IsEqual();
		eq[28][i].in[0] <== in[i];
		eq[28][i].in[1] <== 180;
		eq[29][i] = IsEqual();
		eq[29][i].in[0] <== in[i];
		eq[29][i].in[1] <== 181;
		eq[30][i] = IsEqual();
		eq[30][i].in[0] <== in[i];
		eq[30][i].in[1] <== 182;
		eq[31][i] = IsEqual();
		eq[31][i].in[0] <== in[i];
		eq[31][i].in[1] <== 183;
		eq[32][i] = IsEqual();
		eq[32][i].in[0] <== in[i];
		eq[32][i].in[1] <== 184;
		eq[33][i] = IsEqual();
		eq[33][i].in[0] <== in[i];
		eq[33][i].in[1] <== 185;
		eq[34][i] = IsEqual();
		eq[34][i].in[0] <== in[i];
		eq[34][i].in[1] <== 186;
		eq[35][i] = IsEqual();
		eq[35][i].in[0] <== in[i];
		eq[35][i].in[1] <== 187;
		eq[36][i] = IsEqual();
		eq[36][i].in[0] <== in[i];
		eq[36][i].in[1] <== 188;
		eq[37][i] = IsEqual();
		eq[37][i].in[0] <== in[i];
		eq[37][i].in[1] <== 189;
		eq[38][i] = IsEqual();
		eq[38][i].in[0] <== in[i];
		eq[38][i].in[1] <== 190;
		eq[39][i] = IsEqual();
		eq[39][i].in[0] <== in[i];
		eq[39][i].in[1] <== 191;
		and[36][i] = AND();
		and[36][i].a <== states[i][28];
		multi_or[7][i] = MultiOR(16);
		multi_or[7][i].in[0] <== eq[24][i].out;
		multi_or[7][i].in[1] <== eq[25][i].out;
		multi_or[7][i].in[2] <== eq[26][i].out;
		multi_or[7][i].in[3] <== eq[27][i].out;
		multi_or[7][i].in[4] <== eq[28][i].out;
		multi_or[7][i].in[5] <== eq[29][i].out;
		multi_or[7][i].in[6] <== eq[30][i].out;
		multi_or[7][i].in[7] <== eq[31][i].out;
		multi_or[7][i].in[8] <== eq[32][i].out;
		multi_or[7][i].in[9] <== eq[33][i].out;
		multi_or[7][i].in[10] <== eq[34][i].out;
		multi_or[7][i].in[11] <== eq[35][i].out;
		multi_or[7][i].in[12] <== eq[36][i].out;
		multi_or[7][i].in[13] <== eq[37][i].out;
		multi_or[7][i].in[14] <== eq[38][i].out;
		multi_or[7][i].in[15] <== eq[39][i].out;
		and[36][i].b <== multi_or[7][i].out;
		multi_or[8][i] = MultiOR(2);
		multi_or[8][i].in[0] <== and[35][i].out;
		multi_or[8][i].in[1] <== and[36][i].out;
		states[i+1][29] <== multi_or[8][i].out;
		and[37][i] = AND();
		and[37][i].a <== states[i][29];
		and[37][i].b <== eq[17][i].out;
		states[i+1][30] <== and[37][i].out;
		eq[40][i] = IsEqual();
		eq[40][i].in[0] <== in[i];
		eq[40][i].in[1] <== 67;
		and[38][i] = AND();
		and[38][i].a <== states[i][30];
		and[38][i].b <== eq[40][i].out;
		states[i+1][31] <== and[38][i].out;
		eq[41][i] = IsEqual();
		eq[41][i].in[0] <== in[i];
		eq[41][i].in[1] <== 121;
		and[39][i] = AND();
		and[39][i].a <== states[i][31];
		and[39][i].b <== eq[41][i].out;
		states[i+1][32] <== and[39][i].out;
		and[40][i] = AND();
		and[40][i].a <== states[i][32];
		and[40][i].b <== eq[19][i].out;
		states[i+1][33] <== and[40][i].out;
		and[41][i] = AND();
		and[41][i].a <== states[i][33];
		and[41][i].b <== eq[3][i].out;
		states[i+1][34] <== and[41][i].out;
		eq[42][i] = IsEqual();
		eq[42][i].in[0] <== in[i];
		eq[42][i].in[1] <== 108;
		and[42][i] = AND();
		and[42][i].a <== states[i][34];
		and[42][i].b <== eq[42][i].out;
		states[i+1][35] <== and[42][i].out;
		and[43][i] = AND();
		and[43][i].a <== states[i][35];
		and[43][i].b <== eq[42][i].out;
		states[i+1][36] <== and[43][i].out;
		and[44][i] = AND();
		and[44][i].a <== states[i][36];
		and[44][i].b <== eq[3][i].out;
		states[i+1][37] <== and[44][i].out;
		eq[43][i] = IsEqual();
		eq[43][i].in[0] <== in[i];
		eq[43][i].in[1] <== 99;
		and[45][i] = AND();
		and[45][i].a <== states[i][37];
		and[45][i].b <== eq[43][i].out;
		states[i+1][38] <== and[45][i].out;
		and[46][i] = AND();
		and[46][i].a <== states[i][38];
		and[46][i].b <== eq[11][i].out;
		states[i+1][39] <== and[46][i].out;
		eq[44][i] = IsEqual();
		eq[44][i].in[0] <== in[i];
		eq[44][i].in[1] <== 208;
		eq[45][i] = IsEqual();
		eq[45][i].in[0] <== in[i];
		eq[45][i].in[1] <== 209;
		eq[46][i] = IsEqual();
		eq[46][i].in[0] <== in[i];
		eq[46][i].in[1] <== 210;
		eq[47][i] = IsEqual();
		eq[47][i].in[0] <== in[i];
		eq[47][i].in[1] <== 211;
		and[47][i] = AND();
		and[47][i].a <== states[i][39];
		multi_or[9][i] = MultiOR(4);
		multi_or[9][i].in[0] <== eq[44][i].out;
		multi_or[9][i].in[1] <== eq[45][i].out;
		multi_or[9][i].in[2] <== eq[46][i].out;
		multi_or[9][i].in[3] <== eq[47][i].out;
		and[47][i].b <== multi_or[9][i].out;
		and[48][i] = AND();
		and[48][i].a <== states[i][41];
		and[48][i].b <== multi_or[9][i].out;
		multi_or[10][i] = MultiOR(2);
		multi_or[10][i].in[0] <== and[47][i].out;
		multi_or[10][i].in[1] <== and[48][i].out;
		states[i+1][40] <== multi_or[10][i].out;
		and[49][i] = AND();
		and[49][i].a <== states[i][40];
		and[49][i].b <== and[20][i].out;
		states[i+1][41] <== and[49][i].out;
		and[50][i] = AND();
		and[50][i].a <== states[i][41];
		and[50][i].b <== eq[17][i].out;
		states[i+1][42] <== and[50][i].out;
		eq[48][i] = IsEqual();
		eq[48][i].in[0] <== in[i];
		eq[48][i].in[1] <== 65;
		and[51][i] = AND();
		and[51][i].a <== states[i][42];
		and[51][i].b <== eq[48][i].out;
		states[i+1][43] <== and[51][i].out;
		and[52][i] = AND();
		and[52][i].a <== states[i][43];
		and[52][i].b <== eq[19][i].out;
		states[i+1][44] <== and[52][i].out;
		and[53][i] = AND();
		and[53][i].a <== states[i][44];
		and[53][i].b <== eq[1][i].out;
		states[i+1][45] <== and[53][i].out;
		eq[49][i] = IsEqual();
		eq[49][i].in[0] <== in[i];
		eq[49][i].in[1] <== 98;
		and[54][i] = AND();
		and[54][i].a <== states[i][45];
		and[54][i].b <== eq[49][i].out;
		states[i+1][46] <== and[54][i].out;
		and[55][i] = AND();
		and[55][i].a <== states[i][46];
		and[55][i].b <== eq[3][i].out;
		states[i+1][47] <== and[55][i].out;
		and[56][i] = AND();
		and[56][i].a <== states[i][47];
		and[56][i].b <== eq[43][i].out;
		states[i+1][48] <== and[56][i].out;
		and[57][i] = AND();
		and[57][i].a <== states[i][48];
		and[57][i].b <== eq[11][i].out;
		states[i+1][49] <== and[57][i].out;
		eq[50][i] = IsEqual();
		eq[50][i].in[0] <== in[i];
		eq[50][i].in[1] <== 216;
		eq[51][i] = IsEqual();
		eq[51][i].in[0] <== in[i];
		eq[51][i].in[1] <== 217;
		eq[52][i] = IsEqual();
		eq[52][i].in[0] <== in[i];
		eq[52][i].in[1] <== 218;
		eq[53][i] = IsEqual();
		eq[53][i].in[0] <== in[i];
		eq[53][i].in[1] <== 219;
		and[58][i] = AND();
		and[58][i].a <== states[i][49];
		multi_or[11][i] = MultiOR(4);
		multi_or[11][i].in[0] <== eq[50][i].out;
		multi_or[11][i].in[1] <== eq[51][i].out;
		multi_or[11][i].in[2] <== eq[52][i].out;
		multi_or[11][i].in[3] <== eq[53][i].out;
		and[58][i].b <== multi_or[11][i].out;
		and[59][i] = AND();
		and[59][i].a <== states[i][51];
		and[59][i].b <== multi_or[11][i].out;
		multi_or[12][i] = MultiOR(2);
		multi_or[12][i].in[0] <== and[58][i].out;
		multi_or[12][i].in[1] <== and[59][i].out;
		states[i+1][50] <== multi_or[12][i].out;
		and[60][i] = AND();
		and[60][i].a <== states[i][50];
		and[60][i].b <== and[20][i].out;
		states[i+1][51] <== and[60][i].out;
		and[61][i] = AND();
		and[61][i].a <== states[i][51];
		and[61][i].b <== eq[17][i].out;
		states[i+1][52] <== and[61][i].out;
		eq[54][i] = IsEqual();
		eq[54][i].in[0] <== in[i];
		eq[54][i].in[1] <== 68;
		and[62][i] = AND();
		and[62][i].a <== states[i][52];
		and[62][i].b <== eq[54][i].out;
		states[i+1][53] <== and[62][i].out;
		and[63][i] = AND();
		and[63][i].a <== states[i][53];
		and[63][i].b <== eq[8][i].out;
		states[i+1][54] <== and[63][i].out;
		eq[55][i] = IsEqual();
		eq[55][i].in[0] <== in[i];
		eq[55][i].in[1] <== 118;
		and[64][i] = AND();
		and[64][i].a <== states[i][54];
		and[64][i].b <== eq[55][i].out;
		states[i+1][55] <== and[64][i].out;
		and[65][i] = AND();
		and[65][i].a <== states[i][55];
		and[65][i].b <== eq[1][i].out;
		states[i+1][56] <== and[65][i].out;
		and[66][i] = AND();
		and[66][i].a <== states[i][56];
		and[66][i].b <== eq[4][i].out;
		states[i+1][57] <== and[66][i].out;
		and[67][i] = AND();
		and[67][i].a <== states[i][57];
		and[67][i].b <== eq[1][i].out;
		states[i+1][58] <== and[67][i].out;
		eq[56][i] = IsEqual();
		eq[56][i].in[0] <== in[i];
		eq[56][i].in[1] <== 103;
		and[68][i] = AND();
		and[68][i].a <== states[i][58];
		and[68][i].b <== eq[56][i].out;
		states[i+1][59] <== and[68][i].out;
		and[69][i] = AND();
		and[69][i].a <== states[i][59];
		and[69][i].b <== eq[1][i].out;
		states[i+1][60] <== and[69][i].out;
		and[70][i] = AND();
		and[70][i].a <== states[i][60];
		and[70][i].b <== eq[19][i].out;
		states[i+1][61] <== and[70][i].out;
		and[71][i] = AND();
		and[71][i].a <== states[i][61];
		and[71][i].b <== eq[3][i].out;
		states[i+1][62] <== and[71][i].out;
		and[72][i] = AND();
		and[72][i].a <== states[i][62];
		and[72][i].b <== eq[11][i].out;
		states[i+1][63] <== and[72][i].out;
		eq[57][i] = IsEqual();
		eq[57][i].in[0] <== in[i];
		eq[57][i].in[1] <== 224;
		and[73][i] = AND();
		and[73][i].a <== states[i][63];
		and[73][i].b <== eq[57][i].out;
		and[74][i] = AND();
		and[74][i].a <== states[i][66];
		and[74][i].b <== eq[57][i].out;
		multi_or[13][i] = MultiOR(2);
		multi_or[13][i].in[0] <== and[73][i].out;
		multi_or[13][i].in[1] <== and[74][i].out;
		states[i+1][64] <== multi_or[13][i].out;
		eq[58][i] = IsEqual();
		eq[58][i].in[0] <== in[i];
		eq[58][i].in[1] <== 164;
		eq[59][i] = IsEqual();
		eq[59][i].in[0] <== in[i];
		eq[59][i].in[1] <== 165;
		and[75][i] = AND();
		and[75][i].a <== states[i][64];
		multi_or[14][i] = MultiOR(2);
		multi_or[14][i].in[0] <== eq[58][i].out;
		multi_or[14][i].in[1] <== eq[59][i].out;
		and[75][i].b <== multi_or[14][i].out;
		states[i+1][65] <== and[75][i].out;
		and[76][i] = AND();
		and[76][i].a <== states[i][65];
		and[76][i].b <== and[20][i].out;
		states[i+1][66] <== and[76][i].out;
		and[77][i] = AND();
		and[77][i].a <== states[i][66];
		and[77][i].b <== eq[17][i].out;
		states[i+1][67] <== and[77][i].out;
		eq[60][i] = IsEqual();
		eq[60][i].in[0] <== in[i];
		eq[60][i].in[1] <== 72;
		and[78][i] = AND();
		and[78][i].a <== states[i][67];
		and[78][i].b <== eq[60][i].out;
		states[i+1][68] <== and[78][i].out;
		and[79][i] = AND();
		and[79][i].a <== states[i][68];
		and[79][i].b <== eq[3][i].out;
		states[i+1][69] <== and[79][i].out;
		and[80][i] = AND();
		and[80][i].a <== states[i][69];
		and[80][i].b <== eq[19][i].out;
		states[i+1][70] <== and[80][i].out;
		and[81][i] = AND();
		and[81][i].a <== states[i][70];
		and[81][i].b <== eq[1][i].out;
		states[i+1][71] <== and[81][i].out;
		and[82][i] = AND();
		and[82][i].a <== states[i][71];
		and[82][i].b <== eq[56][i].out;
		states[i+1][72] <== and[82][i].out;
		and[83][i] = AND();
		and[83][i].a <== states[i][72];
		and[83][i].b <== eq[1][i].out;
		states[i+1][73] <== and[83][i].out;
		and[84][i] = AND();
		and[84][i].a <== states[i][73];
		and[84][i].b <== eq[4][i].out;
		states[i+1][74] <== and[84][i].out;
		and[85][i] = AND();
		and[85][i].a <== states[i][74];
		and[85][i].b <== eq[1][i].out;
		states[i+1][75] <== and[85][i].out;
		eq[61][i] = IsEqual();
		eq[61][i].in[0] <== in[i];
		eq[61][i].in[1] <== 38;
		and[86][i] = AND();
		and[86][i].a <== states[i][75];
		and[86][i].b <== eq[61][i].out;
		states[i+1][76] <== and[86][i].out;
		eq[62][i] = IsEqual();
		eq[62][i].in[0] <== in[i];
		eq[62][i].in[1] <== 75;
		and[87][i] = AND();
		and[87][i].a <== states[i][76];
		and[87][i].b <== eq[62][i].out;
		states[i+1][77] <== and[87][i].out;
		and[88][i] = AND();
		and[88][i].a <== states[i][77];
		and[88][i].b <== eq[1][i].out;
		states[i+1][78] <== and[88][i].out;
		and[89][i] = AND();
		and[89][i].a <== states[i][78];
		and[89][i].b <== eq[2][i].out;
		states[i+1][79] <== and[89][i].out;
		and[90][i] = AND();
		and[90][i].a <== states[i][79];
		and[90][i].b <== eq[1][i].out;
		states[i+1][80] <== and[90][i].out;
		and[91][i] = AND();
		and[91][i].a <== states[i][80];
		and[91][i].b <== eq[20][i].out;
		states[i+1][81] <== and[91][i].out;
		and[92][i] = AND();
		and[92][i].a <== states[i][81];
		and[92][i].b <== eq[1][i].out;
		states[i+1][82] <== and[92][i].out;
		and[93][i] = AND();
		and[93][i].a <== states[i][82];
		and[93][i].b <== eq[4][i].out;
		states[i+1][83] <== and[93][i].out;
		and[94][i] = AND();
		and[94][i].a <== states[i][83];
		and[94][i].b <== eq[1][i].out;
		states[i+1][84] <== and[94][i].out;
		and[95][i] = AND();
		and[95][i].a <== states[i][84];
		and[95][i].b <== eq[11][i].out;
		states[i+1][85] <== and[95][i].out;
		eq[63][i] = IsEqual();
		eq[63][i].in[0] <== in[i];
		eq[63][i].in[1] <== 227;
		and[96][i] = AND();
		and[96][i].a <== states[i][85];
		and[96][i].b <== eq[63][i].out;
		and[97][i] = AND();
		and[97][i].a <== states[i][89];
		and[97][i].b <== eq[63][i].out;
		multi_or[15][i] = MultiOR(2);
		multi_or[15][i].in[0] <== and[96][i].out;
		multi_or[15][i].in[1] <== and[97][i].out;
		states[i+1][86] <== multi_or[15][i].out;
		eq[64][i] = IsEqual();
		eq[64][i].in[0] <== in[i];
		eq[64][i].in[1] <== 129;
		and[98][i] = AND();
		and[98][i].a <== states[i][86];
		and[98][i].b <== eq[64][i].out;
		states[i+1][87] <== and[98][i].out;
		eq[65][i] = IsEqual();
		eq[65][i].in[0] <== in[i];
		eq[65][i].in[1] <== 130;
		eq[66][i] = IsEqual();
		eq[66][i].in[0] <== in[i];
		eq[66][i].in[1] <== 131;
		and[99][i] = AND();
		and[99][i].a <== states[i][86];
		multi_or[16][i] = MultiOR(2);
		multi_or[16][i].in[0] <== eq[65][i].out;
		multi_or[16][i].in[1] <== eq[66][i].out;
		and[99][i].b <== multi_or[16][i].out;
		states[i+1][88] <== and[99][i].out;
		lt[4][i] = LessEqThan(8);
		lt[4][i].in[0] <== 129;
		lt[4][i].in[1] <== in[i];
		lt[5][i] = LessEqThan(8);
		lt[5][i].in[0] <== in[i];
		lt[5][i].in[1] <== 191;
		and[100][i] = AND();
		and[100][i].a <== lt[4][i].out;
		and[100][i].b <== lt[5][i].out;
		and[101][i] = AND();
		and[101][i].a <== states[i][87];
		and[101][i].b <== and[100][i].out;
		and[102][i] = AND();
		and[102][i].a <== states[i][88];
		and[102][i].b <== and[20][i].out;
		multi_or[17][i] = MultiOR(2);
		multi_or[17][i].in[0] <== and[101][i].out;
		multi_or[17][i].in[1] <== and[102][i].out;
		states[i+1][89] <== multi_or[17][i].out;
		from_zero_enabled[i] <== MultiNOR(89)([states_tmp[i+1][1], states[i+1][2], states[i+1][3], states[i+1][4], states[i+1][5], states[i+1][6], states[i+1][7], states[i+1][8], states[i+1][9], states[i+1][10], states[i+1][11], states[i+1][12], states[i+1][13], states[i+1][14], states[i+1][15], states[i+1][16], states[i+1][17], states[i+1][18], states[i+1][19], states[i+1][20], states[i+1][21], states[i+1][22], states[i+1][23], states[i+1][24], states[i+1][25], states[i+1][26], states[i+1][27], states[i+1][28], states[i+1][29], states[i+1][30], states[i+1][31], states[i+1][32], states[i+1][33], states[i+1][34], states[i+1][35], states[i+1][36], states[i+1][37], states[i+1][38], states[i+1][39], states[i+1][40], states[i+1][41], states[i+1][42], states[i+1][43], states[i+1][44], states[i+1][45], states[i+1][46], states[i+1][47], states[i+1][48], states[i+1][49], states[i+1][50], states[i+1][51], states[i+1][52], states[i+1][53], states[i+1][54], states[i+1][55], states[i+1][56], states[i+1][57], states[i+1][58], states[i+1][59], states[i+1][60], states[i+1][61], states[i+1][62], states[i+1][63], states[i+1][64], states[i+1][65], states[i+1][66], states[i+1][67], states[i+1][68], states[i+1][69], states[i+1][70], states[i+1][71], states[i+1][72], states[i+1][73], states[i+1][74], states[i+1][75], states[i+1][76], states[i+1][77], states[i+1][78], states[i+1][79], states[i+1][80], states[i+1][81], states[i+1][82], states[i+1][83], states[i+1][84], states[i+1][85], states[i+1][86], states[i+1][87], states[i+1][88], states[i+1][89]]);
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
		state_changed[i].in[34] <== states[i+1][35];
		state_changed[i].in[35] <== states[i+1][36];
		state_changed[i].in[36] <== states[i+1][37];
		state_changed[i].in[37] <== states[i+1][38];
		state_changed[i].in[38] <== states[i+1][39];
		state_changed[i].in[39] <== states[i+1][40];
		state_changed[i].in[40] <== states[i+1][41];
		state_changed[i].in[41] <== states[i+1][42];
		state_changed[i].in[42] <== states[i+1][43];
		state_changed[i].in[43] <== states[i+1][44];
		state_changed[i].in[44] <== states[i+1][45];
		state_changed[i].in[45] <== states[i+1][46];
		state_changed[i].in[46] <== states[i+1][47];
		state_changed[i].in[47] <== states[i+1][48];
		state_changed[i].in[48] <== states[i+1][49];
		state_changed[i].in[49] <== states[i+1][50];
		state_changed[i].in[50] <== states[i+1][51];
		state_changed[i].in[51] <== states[i+1][52];
		state_changed[i].in[52] <== states[i+1][53];
		state_changed[i].in[53] <== states[i+1][54];
		state_changed[i].in[54] <== states[i+1][55];
		state_changed[i].in[55] <== states[i+1][56];
		state_changed[i].in[56] <== states[i+1][57];
		state_changed[i].in[57] <== states[i+1][58];
		state_changed[i].in[58] <== states[i+1][59];
		state_changed[i].in[59] <== states[i+1][60];
		state_changed[i].in[60] <== states[i+1][61];
		state_changed[i].in[61] <== states[i+1][62];
		state_changed[i].in[62] <== states[i+1][63];
		state_changed[i].in[63] <== states[i+1][64];
		state_changed[i].in[64] <== states[i+1][65];
		state_changed[i].in[65] <== states[i+1][66];
		state_changed[i].in[66] <== states[i+1][67];
		state_changed[i].in[67] <== states[i+1][68];
		state_changed[i].in[68] <== states[i+1][69];
		state_changed[i].in[69] <== states[i+1][70];
		state_changed[i].in[70] <== states[i+1][71];
		state_changed[i].in[71] <== states[i+1][72];
		state_changed[i].in[72] <== states[i+1][73];
		state_changed[i].in[73] <== states[i+1][74];
		state_changed[i].in[74] <== states[i+1][75];
		state_changed[i].in[75] <== states[i+1][76];
		state_changed[i].in[76] <== states[i+1][77];
		state_changed[i].in[77] <== states[i+1][78];
		state_changed[i].in[78] <== states[i+1][79];
		state_changed[i].in[79] <== states[i+1][80];
		state_changed[i].in[80] <== states[i+1][81];
		state_changed[i].in[81] <== states[i+1][82];
		state_changed[i].in[82] <== states[i+1][83];
		state_changed[i].in[83] <== states[i+1][84];
		state_changed[i].in[84] <== states[i+1][85];
		state_changed[i].in[85] <== states[i+1][86];
		state_changed[i].in[86] <== states[i+1][87];
		state_changed[i].in[87] <== states[i+1][88];
		state_changed[i].in[88] <== states[i+1][89];
	}

	component final_state_result = MultiOR(num_bytes+1);
	for (var i = 0; i <= num_bytes; i++) {
		final_state_result.in[i] <== states[i][89];
	}
	out <== final_state_result.out;
	signal is_consecutive[msg_bytes+1][3];
	is_consecutive[msg_bytes][2] <== 0;
	for (var i = 0; i < msg_bytes; i++) {
		is_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][89] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];
		is_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];
		is_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][89], is_consecutive[msg_bytes-1-i][1]]);
	}
	// substrings calculated: [{(16, 17), (16, 18), (17, 19), (18, 19), (19, 17), (19, 18)}, {(26, 27), (26, 28), (27, 29), (28, 29), (29, 27), (29, 28)}, {(39, 40), (40, 41), (41, 40)}, {(49, 50), (50, 51), (51, 50)}, {(63, 64), (64, 65), (65, 66), (66, 64)}, {(85, 86), (86, 87), (86, 88), (87, 89), (88, 89), (89, 86)}]
	signal prev_states0[6][msg_bytes];
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(16, 17), (16, 18), (17, 19), (18, 19), (19, 17), (19, 18)]
		prev_states0[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][16];
		prev_states0[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][16];
		prev_states0[2][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][17];
		prev_states0[3][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][18];
		prev_states0[4][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][19];
		prev_states0[5][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][19];
		is_substr0[i] <== MultiOR(6)([prev_states0[0][i] * states[i+2][17], prev_states0[1][i] * states[i+2][18], prev_states0[2][i] * states[i+2][19], prev_states0[3][i] * states[i+2][19], prev_states0[4][i] * states[i+2][17], prev_states0[5][i] * states[i+2][18]]);
		is_reveal0[i] <== is_substr0[i] * is_consecutive[i][2];
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
	signal prev_states1[6][msg_bytes];
	signal is_substr1[msg_bytes];
	signal is_reveal1[msg_bytes];
	signal output reveal1[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 1-th substring transitions: [(26, 27), (26, 28), (27, 29), (28, 29), (29, 27), (29, 28)]
		prev_states1[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][26];
		prev_states1[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][26];
		prev_states1[2][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][27];
		prev_states1[3][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][28];
		prev_states1[4][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][29];
		prev_states1[5][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][29];
		is_substr1[i] <== MultiOR(6)([prev_states1[0][i] * states[i+2][27], prev_states1[1][i] * states[i+2][28], prev_states1[2][i] * states[i+2][29], prev_states1[3][i] * states[i+2][29], prev_states1[4][i] * states[i+2][27], prev_states1[5][i] * states[i+2][28]]);
		is_reveal1[i] <== is_substr1[i] * is_consecutive[i][2];
		reveal1[i] <== in[i+1] * is_reveal1[i];
	}
	signal prev_states2[3][msg_bytes];
	signal is_substr2[msg_bytes];
	signal is_reveal2[msg_bytes];
	signal output reveal2[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 2-th substring transitions: [(39, 40), (40, 41), (41, 40)]
		prev_states2[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][39];
		prev_states2[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][40];
		prev_states2[2][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][41];
		is_substr2[i] <== MultiOR(3)([prev_states2[0][i] * states[i+2][40], prev_states2[1][i] * states[i+2][41], prev_states2[2][i] * states[i+2][40]]);
		is_reveal2[i] <== is_substr2[i] * is_consecutive[i][2];
		reveal2[i] <== in[i+1] * is_reveal2[i];
	}
	signal prev_states3[3][msg_bytes];
	signal is_substr3[msg_bytes];
	signal is_reveal3[msg_bytes];
	signal output reveal3[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 3-th substring transitions: [(49, 50), (50, 51), (51, 50)]
		prev_states3[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][49];
		prev_states3[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][50];
		prev_states3[2][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][51];
		is_substr3[i] <== MultiOR(3)([prev_states3[0][i] * states[i+2][50], prev_states3[1][i] * states[i+2][51], prev_states3[2][i] * states[i+2][50]]);
		is_reveal3[i] <== is_substr3[i] * is_consecutive[i][2];
		reveal3[i] <== in[i+1] * is_reveal3[i];
	}
	signal prev_states4[4][msg_bytes];
	signal is_substr4[msg_bytes];
	signal is_reveal4[msg_bytes];
	signal output reveal4[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 4-th substring transitions: [(63, 64), (64, 65), (65, 66), (66, 64)]
		prev_states4[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][63];
		prev_states4[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][64];
		prev_states4[2][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][65];
		prev_states4[3][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][66];
		is_substr4[i] <== MultiOR(4)([prev_states4[0][i] * states[i+2][64], prev_states4[1][i] * states[i+2][65], prev_states4[2][i] * states[i+2][66], prev_states4[3][i] * states[i+2][64]]);
		is_reveal4[i] <== is_substr4[i] * is_consecutive[i][2];
		reveal4[i] <== in[i+1] * is_reveal4[i];
	}
	signal prev_states5[6][msg_bytes];
	signal is_substr5[msg_bytes];
	signal is_reveal5[msg_bytes];
	signal output reveal5[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 5-th substring transitions: [(85, 86), (86, 87), (86, 88), (87, 89), (88, 89), (89, 86)]
		prev_states5[0][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][85];
		prev_states5[1][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][86];
		prev_states5[2][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][86];
		prev_states5[3][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][87];
		prev_states5[4][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][88];
		prev_states5[5][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][89];
		is_substr5[i] <== MultiOR(6)([prev_states5[0][i] * states[i+2][86], prev_states5[1][i] * states[i+2][87], prev_states5[2][i] * states[i+2][88], prev_states5[3][i] * states[i+2][89], prev_states5[4][i] * states[i+2][89], prev_states5[5][i] * states[i+2][86]]);
		is_reveal5[i] <== is_substr5[i] * is_consecutive[i][2];
		reveal5[i] <== in[i+1] * is_reveal5[i];
	}
}