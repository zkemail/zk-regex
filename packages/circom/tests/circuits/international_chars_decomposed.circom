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

	component eq[18][num_bytes];
	component and[100][num_bytes];
	component multi_or[15][num_bytes];
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
		eq[0][i].in[1] <== 7;
		and[0][i] = AND();
		and[0][i].a <== states[i][0];
		and[0][i].b <== eq[0][i].out;
		states_tmp[i+1][1] <== 0;
		eq[1][i] = IsEqual();
		eq[1][i].in[0] <== in[i];
		eq[1][i].in[1] <== 9;
		and[1][i] = AND();
		and[1][i].a <== states[i][1];
		and[1][i].b <== eq[1][i].out;
		states[i+1][2] <== and[1][i].out;
		eq[2][i] = IsEqual();
		eq[2][i].in[0] <== in[i];
		eq[2][i].in[1] <== 19;
		and[2][i] = AND();
		and[2][i].a <== states[i][2];
		and[2][i].b <== eq[2][i].out;
		states[i+1][3] <== and[2][i].out;
		eq[3][i] = IsEqual();
		eq[3][i].in[0] <== in[i];
		eq[3][i].in[1] <== 13;
		and[3][i] = AND();
		and[3][i].a <== states[i][3];
		and[3][i].b <== eq[3][i].out;
		states[i+1][4] <== and[3][i].out;
		eq[4][i] = IsEqual();
		eq[4][i].in[0] <== in[i];
		eq[4][i].in[1] <== 15;
		and[4][i] = AND();
		and[4][i].a <== states[i][4];
		and[4][i].b <== eq[4][i].out;
		states[i+1][5] <== and[4][i].out;
		eq[5][i] = IsEqual();
		eq[5][i].in[0] <== in[i];
		eq[5][i].in[1] <== 1;
		and[5][i] = AND();
		and[5][i].a <== states[i][5];
		and[5][i].b <== eq[5][i].out;
		states[i+1][6] <== and[5][i].out;
		eq[6][i] = IsEqual();
		eq[6][i].in[0] <== in[i];
		eq[6][i].in[1] <== 5;
		and[6][i] = AND();
		and[6][i].a <== states[i][6];
		and[6][i].b <== eq[6][i].out;
		states[i+1][7] <== and[6][i].out;
		eq[7][i] = IsEqual();
		eq[7][i].in[0] <== in[i];
		eq[7][i].in[1] <== 21;
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
		eq[8][i].in[1] <== 11;
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
		eq[9][i].in[1] <== 18;
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
		eq[10][i].in[1] <== 16;
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
		eq[11][i].in[1] <== 3;
		and[15][i] = AND();
		and[15][i].a <== states[i][15];
		and[15][i].b <== eq[11][i].out;
		states[i+1][16] <== and[15][i].out;
		and[16][i] = AND();
		and[16][i].a <== states[i][16];
		and[16][i].b <== eq[6][i].out;
		and[17][i] = AND();
		and[17][i].a <== states[i][19];
		and[17][i].b <== eq[6][i].out;
		multi_or[0][i] = MultiOR(2);
		multi_or[0][i].in[0] <== and[16][i].out;
		multi_or[0][i].in[1] <== and[17][i].out;
		states[i+1][17] <== multi_or[0][i].out;
		eq[12][i] = IsEqual();
		eq[12][i].in[0] <== in[i];
		eq[12][i].in[1] <== 4;
		and[18][i] = AND();
		and[18][i].a <== states[i][16];
		and[18][i].b <== eq[12][i].out;
		and[19][i] = AND();
		and[19][i].a <== states[i][19];
		and[19][i].b <== eq[12][i].out;
		multi_or[1][i] = MultiOR(2);
		multi_or[1][i].in[0] <== and[18][i].out;
		multi_or[1][i].in[1] <== and[19][i].out;
		states[i+1][18] <== multi_or[1][i].out;
		eq[13][i] = IsEqual();
		eq[13][i].in[0] <== in[i];
		eq[13][i].in[1] <== 2;
		and[20][i] = AND();
		and[20][i].a <== states[i][17];
		multi_or[2][i] = MultiOR(2);
		multi_or[2][i].in[0] <== eq[5][i].out;
		multi_or[2][i].in[1] <== eq[13][i].out;
		and[20][i].b <== multi_or[2][i].out;
		and[21][i] = AND();
		and[21][i].a <== states[i][18];
		and[21][i].b <== eq[13][i].out;
		multi_or[3][i] = MultiOR(2);
		multi_or[3][i].in[0] <== and[20][i].out;
		multi_or[3][i].in[1] <== and[21][i].out;
		states[i+1][19] <== multi_or[3][i].out;
		and[22][i] = AND();
		and[22][i].a <== states[i][19];
		and[22][i].b <== eq[5][i].out;
		states[i+1][20] <== and[22][i].out;
		and[23][i] = AND();
		and[23][i].a <== states[i][20];
		and[23][i].b <== eq[6][i].out;
		states[i+1][21] <== and[23][i].out;
		and[24][i] = AND();
		and[24][i].a <== states[i][21];
		and[24][i].b <== eq[8][i].out;
		states[i+1][22] <== and[24][i].out;
		and[25][i] = AND();
		and[25][i].a <== states[i][22];
		and[25][i].b <== eq[0][i].out;
		states[i+1][23] <== and[25][i].out;
		and[26][i] = AND();
		and[26][i].a <== states[i][23];
		and[26][i].b <== eq[0][i].out;
		states[i+1][24] <== and[26][i].out;
		and[27][i] = AND();
		and[27][i].a <== states[i][24];
		and[27][i].b <== eq[1][i].out;
		states[i+1][25] <== and[27][i].out;
		and[28][i] = AND();
		and[28][i].a <== states[i][25];
		and[28][i].b <== eq[11][i].out;
		states[i+1][26] <== and[28][i].out;
		and[29][i] = AND();
		and[29][i].a <== states[i][26];
		and[29][i].b <== eq[6][i].out;
		and[30][i] = AND();
		and[30][i].a <== states[i][29];
		and[30][i].b <== eq[6][i].out;
		multi_or[4][i] = MultiOR(2);
		multi_or[4][i].in[0] <== and[29][i].out;
		multi_or[4][i].in[1] <== and[30][i].out;
		states[i+1][27] <== multi_or[4][i].out;
		and[31][i] = AND();
		and[31][i].a <== states[i][26];
		and[31][i].b <== eq[12][i].out;
		and[32][i] = AND();
		and[32][i].a <== states[i][29];
		and[32][i].b <== eq[12][i].out;
		multi_or[5][i] = MultiOR(2);
		multi_or[5][i].in[0] <== and[31][i].out;
		multi_or[5][i].in[1] <== and[32][i].out;
		states[i+1][28] <== multi_or[5][i].out;
		and[33][i] = AND();
		and[33][i].a <== states[i][27];
		and[33][i].b <== multi_or[2][i].out;
		and[34][i] = AND();
		and[34][i].a <== states[i][28];
		and[34][i].b <== eq[13][i].out;
		multi_or[6][i] = MultiOR(2);
		multi_or[6][i].in[0] <== and[33][i].out;
		multi_or[6][i].in[1] <== and[34][i].out;
		states[i+1][29] <== multi_or[6][i].out;
		and[35][i] = AND();
		and[35][i].a <== states[i][29];
		and[35][i].b <== eq[5][i].out;
		states[i+1][30] <== and[35][i].out;
		and[36][i] = AND();
		and[36][i].a <== states[i][30];
		and[36][i].b <== eq[6][i].out;
		states[i+1][31] <== and[36][i].out;
		and[37][i] = AND();
		and[37][i].a <== states[i][31];
		and[37][i].b <== eq[4][i].out;
		states[i+1][32] <== and[37][i].out;
		and[38][i] = AND();
		and[38][i].a <== states[i][32];
		and[38][i].b <== eq[3][i].out;
		states[i+1][33] <== and[38][i].out;
		and[39][i] = AND();
		and[39][i].a <== states[i][33];
		and[39][i].b <== eq[1][i].out;
		states[i+1][34] <== and[39][i].out;
		and[40][i] = AND();
		and[40][i].a <== states[i][34];
		and[40][i].b <== eq[8][i].out;
		states[i+1][35] <== and[40][i].out;
		and[41][i] = AND();
		and[41][i].a <== states[i][35];
		and[41][i].b <== eq[8][i].out;
		states[i+1][36] <== and[41][i].out;
		and[42][i] = AND();
		and[42][i].a <== states[i][36];
		and[42][i].b <== eq[1][i].out;
		states[i+1][37] <== and[42][i].out;
		and[43][i] = AND();
		and[43][i].a <== states[i][37];
		and[43][i].b <== eq[0][i].out;
		states[i+1][38] <== and[43][i].out;
		and[44][i] = AND();
		and[44][i].a <== states[i][38];
		and[44][i].b <== eq[11][i].out;
		states[i+1][39] <== and[44][i].out;
		and[45][i] = AND();
		and[45][i].a <== states[i][39];
		and[45][i].b <== eq[11][i].out;
		and[46][i] = AND();
		and[46][i].a <== states[i][41];
		and[46][i].b <== eq[11][i].out;
		multi_or[7][i] = MultiOR(2);
		multi_or[7][i].in[0] <== and[45][i].out;
		multi_or[7][i].in[1] <== and[46][i].out;
		states[i+1][40] <== multi_or[7][i].out;
		and[47][i] = AND();
		and[47][i].a <== states[i][40];
		and[47][i].b <== eq[5][i].out;
		states[i+1][41] <== and[47][i].out;
		and[48][i] = AND();
		and[48][i].a <== states[i][41];
		and[48][i].b <== eq[5][i].out;
		states[i+1][42] <== and[48][i].out;
		and[49][i] = AND();
		and[49][i].a <== states[i][42];
		and[49][i].b <== eq[6][i].out;
		states[i+1][43] <== and[49][i].out;
		and[50][i] = AND();
		and[50][i].a <== states[i][43];
		and[50][i].b <== eq[3][i].out;
		states[i+1][44] <== and[50][i].out;
		and[51][i] = AND();
		and[51][i].a <== states[i][44];
		and[51][i].b <== eq[0][i].out;
		states[i+1][45] <== and[51][i].out;
		eq[14][i] = IsEqual();
		eq[14][i].in[0] <== in[i];
		eq[14][i].in[1] <== 8;
		and[52][i] = AND();
		and[52][i].a <== states[i][45];
		and[52][i].b <== eq[14][i].out;
		states[i+1][46] <== and[52][i].out;
		and[53][i] = AND();
		and[53][i].a <== states[i][46];
		and[53][i].b <== eq[8][i].out;
		states[i+1][47] <== and[53][i].out;
		and[54][i] = AND();
		and[54][i].a <== states[i][47];
		and[54][i].b <== eq[1][i].out;
		states[i+1][48] <== and[54][i].out;
		and[55][i] = AND();
		and[55][i].a <== states[i][48];
		and[55][i].b <== eq[11][i].out;
		states[i+1][49] <== and[55][i].out;
		and[56][i] = AND();
		and[56][i].a <== states[i][49];
		and[56][i].b <== eq[11][i].out;
		and[57][i] = AND();
		and[57][i].a <== states[i][51];
		and[57][i].b <== eq[11][i].out;
		multi_or[8][i] = MultiOR(2);
		multi_or[8][i].in[0] <== and[56][i].out;
		multi_or[8][i].in[1] <== and[57][i].out;
		states[i+1][50] <== multi_or[8][i].out;
		and[58][i] = AND();
		and[58][i].a <== states[i][50];
		and[58][i].b <== eq[5][i].out;
		states[i+1][51] <== and[58][i].out;
		and[59][i] = AND();
		and[59][i].a <== states[i][51];
		and[59][i].b <== eq[5][i].out;
		states[i+1][52] <== and[59][i].out;
		and[60][i] = AND();
		and[60][i].a <== states[i][52];
		and[60][i].b <== eq[6][i].out;
		states[i+1][53] <== and[60][i].out;
		and[61][i] = AND();
		and[61][i].a <== states[i][53];
		and[61][i].b <== eq[1][i].out;
		states[i+1][54] <== and[61][i].out;
		and[62][i] = AND();
		and[62][i].a <== states[i][54];
		and[62][i].b <== eq[2][i].out;
		states[i+1][55] <== and[62][i].out;
		and[63][i] = AND();
		and[63][i].a <== states[i][55];
		and[63][i].b <== eq[0][i].out;
		states[i+1][56] <== and[63][i].out;
		and[64][i] = AND();
		and[64][i].a <== states[i][56];
		and[64][i].b <== eq[4][i].out;
		states[i+1][57] <== and[64][i].out;
		and[65][i] = AND();
		and[65][i].a <== states[i][57];
		and[65][i].b <== eq[0][i].out;
		states[i+1][58] <== and[65][i].out;
		and[66][i] = AND();
		and[66][i].a <== states[i][58];
		and[66][i].b <== eq[8][i].out;
		states[i+1][59] <== and[66][i].out;
		and[67][i] = AND();
		and[67][i].a <== states[i][59];
		and[67][i].b <== eq[0][i].out;
		states[i+1][60] <== and[67][i].out;
		eq[15][i] = IsEqual();
		eq[15][i].in[0] <== in[i];
		eq[15][i].in[1] <== 17;
		and[68][i] = AND();
		and[68][i].a <== states[i][60];
		and[68][i].b <== eq[15][i].out;
		states[i+1][61] <== and[68][i].out;
		and[69][i] = AND();
		and[69][i].a <== states[i][61];
		and[69][i].b <== eq[3][i].out;
		states[i+1][62] <== and[69][i].out;
		and[70][i] = AND();
		and[70][i].a <== states[i][62];
		and[70][i].b <== eq[11][i].out;
		states[i+1][63] <== and[70][i].out;
		and[71][i] = AND();
		and[71][i].a <== states[i][63];
		and[71][i].b <== eq[6][i].out;
		and[72][i] = AND();
		and[72][i].a <== states[i][66];
		and[72][i].b <== eq[6][i].out;
		multi_or[9][i] = MultiOR(2);
		multi_or[9][i].in[0] <== and[71][i].out;
		multi_or[9][i].in[1] <== and[72][i].out;
		states[i+1][64] <== multi_or[9][i].out;
		and[73][i] = AND();
		and[73][i].a <== states[i][64];
		and[73][i].b <== eq[13][i].out;
		states[i+1][65] <== and[73][i].out;
		and[74][i] = AND();
		and[74][i].a <== states[i][65];
		multi_or[10][i] = MultiOR(3);
		multi_or[10][i].in[0] <== eq[5][i].out;
		multi_or[10][i].in[1] <== eq[13][i].out;
		multi_or[10][i].in[2] <== eq[11][i].out;
		and[74][i].b <== multi_or[10][i].out;
		states[i+1][66] <== and[74][i].out;
		and[75][i] = AND();
		and[75][i].a <== states[i][66];
		and[75][i].b <== eq[5][i].out;
		states[i+1][67] <== and[75][i].out;
		and[76][i] = AND();
		and[76][i].a <== states[i][67];
		and[76][i].b <== eq[0][i].out;
		states[i+1][68] <== and[76][i].out;
		and[77][i] = AND();
		and[77][i].a <== states[i][68];
		and[77][i].b <== eq[4][i].out;
		states[i+1][69] <== and[77][i].out;
		and[78][i] = AND();
		and[78][i].a <== states[i][69];
		and[78][i].b <== eq[7][i].out;
		states[i+1][70] <== and[78][i].out;
		and[79][i] = AND();
		and[79][i].a <== states[i][70];
		and[79][i].b <== eq[8][i].out;
		states[i+1][71] <== and[79][i].out;
		and[80][i] = AND();
		and[80][i].a <== states[i][71];
		and[80][i].b <== eq[3][i].out;
		states[i+1][72] <== and[80][i].out;
		and[81][i] = AND();
		and[81][i].a <== states[i][72];
		and[81][i].b <== eq[8][i].out;
		states[i+1][73] <== and[81][i].out;
		and[82][i] = AND();
		and[82][i].a <== states[i][73];
		and[82][i].b <== eq[2][i].out;
		states[i+1][74] <== and[82][i].out;
		and[83][i] = AND();
		and[83][i].a <== states[i][74];
		and[83][i].b <== eq[8][i].out;
		states[i+1][75] <== and[83][i].out;
		and[84][i] = AND();
		and[84][i].a <== states[i][75];
		and[84][i].b <== eq[11][i].out;
		states[i+1][76] <== and[84][i].out;
		and[85][i] = AND();
		and[85][i].a <== states[i][76];
		and[85][i].b <== eq[1][i].out;
		states[i+1][77] <== and[85][i].out;
		and[86][i] = AND();
		and[86][i].a <== states[i][77];
		and[86][i].b <== eq[8][i].out;
		states[i+1][78] <== and[86][i].out;
		eq[16][i] = IsEqual();
		eq[16][i].in[0] <== in[i];
		eq[16][i].in[1] <== 23;
		and[87][i] = AND();
		and[87][i].a <== states[i][78];
		and[87][i].b <== eq[16][i].out;
		states[i+1][79] <== and[87][i].out;
		and[88][i] = AND();
		and[88][i].a <== states[i][79];
		and[88][i].b <== eq[8][i].out;
		states[i+1][80] <== and[88][i].out;
		and[89][i] = AND();
		and[89][i].a <== states[i][80];
		and[89][i].b <== eq[15][i].out;
		states[i+1][81] <== and[89][i].out;
		and[90][i] = AND();
		and[90][i].a <== states[i][81];
		and[90][i].b <== eq[8][i].out;
		states[i+1][82] <== and[90][i].out;
		and[91][i] = AND();
		and[91][i].a <== states[i][82];
		and[91][i].b <== eq[2][i].out;
		states[i+1][83] <== and[91][i].out;
		and[92][i] = AND();
		and[92][i].a <== states[i][83];
		and[92][i].b <== eq[8][i].out;
		states[i+1][84] <== and[92][i].out;
		and[93][i] = AND();
		and[93][i].a <== states[i][84];
		and[93][i].b <== eq[6][i].out;
		states[i+1][85] <== and[93][i].out;
		eq[17][i] = IsEqual();
		eq[17][i].in[0] <== in[i];
		eq[17][i].in[1] <== 6;
		and[94][i] = AND();
		and[94][i].a <== states[i][85];
		and[94][i].b <== eq[17][i].out;
		and[95][i] = AND();
		and[95][i].a <== states[i][89];
		and[95][i].b <== eq[17][i].out;
		multi_or[11][i] = MultiOR(2);
		multi_or[11][i].in[0] <== and[94][i].out;
		multi_or[11][i].in[1] <== and[95][i].out;
		states[i+1][86] <== multi_or[11][i].out;
		and[96][i] = AND();
		and[96][i].a <== states[i][86];
		and[96][i].b <== eq[13][i].out;
		states[i+1][87] <== and[96][i].out;
		and[97][i] = AND();
		and[97][i].a <== states[i][86];
		and[97][i].b <== eq[11][i].out;
		states[i+1][88] <== and[97][i].out;
		and[98][i] = AND();
		and[98][i].a <== states[i][87];
		multi_or[12][i] = MultiOR(3);
		multi_or[12][i].in[0] <== eq[13][i].out;
		multi_or[12][i].in[1] <== eq[11][i].out;
		multi_or[12][i].in[2] <== eq[12][i].out;
		and[98][i].b <== multi_or[12][i].out;
		and[99][i] = AND();
		and[99][i].a <== states[i][88];
		multi_or[13][i] = MultiOR(4);
		multi_or[13][i].in[0] <== eq[5][i].out;
		multi_or[13][i].in[1] <== eq[13][i].out;
		multi_or[13][i].in[2] <== eq[11][i].out;
		multi_or[13][i].in[3] <== eq[12][i].out;
		and[99][i].b <== multi_or[13][i].out;
		multi_or[14][i] = MultiOR(2);
		multi_or[14][i].in[0] <== and[98][i].out;
		multi_or[14][i].in[1] <== and[99][i].out;
		states[i+1][89] <== multi_or[14][i].out;
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
	signal is_substr0[msg_bytes];
	signal is_reveal0[msg_bytes];
	signal output reveal0[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 0-th substring transitions: [(16, 17), (16, 18), (17, 19), (18, 19), (19, 17), (19, 18)]
		is_substr0[i] <== MultiOR(6)([states[i+1][16] * states[i+2][17], states[i+1][16] * states[i+2][18], states[i+1][17] * states[i+2][19], states[i+1][18] * states[i+2][19], states[i+1][19] * states[i+2][17], states[i+1][19] * states[i+2][18]]);
		is_reveal0[i] <== is_substr0[i] * is_consecutive[i][2];
		reveal0[i] <== in[i+1] * is_reveal0[i];
	}
	signal is_substr1[msg_bytes];
	signal is_reveal1[msg_bytes];
	signal output reveal1[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 1-th substring transitions: [(26, 27), (26, 28), (27, 29), (28, 29), (29, 27), (29, 28)]
		is_substr1[i] <== MultiOR(6)([states[i+1][26] * states[i+2][27], states[i+1][26] * states[i+2][28], states[i+1][27] * states[i+2][29], states[i+1][28] * states[i+2][29], states[i+1][29] * states[i+2][27], states[i+1][29] * states[i+2][28]]);
		is_reveal1[i] <== is_substr1[i] * is_consecutive[i][2];
		reveal1[i] <== in[i+1] * is_reveal1[i];
	}
	signal is_substr2[msg_bytes];
	signal is_reveal2[msg_bytes];
	signal output reveal2[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 2-th substring transitions: [(39, 40), (40, 41), (41, 40)]
		is_substr2[i] <== MultiOR(3)([states[i+1][39] * states[i+2][40], states[i+1][40] * states[i+2][41], states[i+1][41] * states[i+2][40]]);
		is_reveal2[i] <== is_substr2[i] * is_consecutive[i][2];
		reveal2[i] <== in[i+1] * is_reveal2[i];
	}
	signal is_substr3[msg_bytes];
	signal is_reveal3[msg_bytes];
	signal output reveal3[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 3-th substring transitions: [(49, 50), (50, 51), (51, 50)]
		is_substr3[i] <== MultiOR(3)([states[i+1][49] * states[i+2][50], states[i+1][50] * states[i+2][51], states[i+1][51] * states[i+2][50]]);
		is_reveal3[i] <== is_substr3[i] * is_consecutive[i][2];
		reveal3[i] <== in[i+1] * is_reveal3[i];
	}
	signal is_substr4[msg_bytes];
	signal is_reveal4[msg_bytes];
	signal output reveal4[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 4-th substring transitions: [(63, 64), (64, 65), (65, 66), (66, 64)]
		is_substr4[i] <== MultiOR(4)([states[i+1][63] * states[i+2][64], states[i+1][64] * states[i+2][65], states[i+1][65] * states[i+2][66], states[i+1][66] * states[i+2][64]]);
		is_reveal4[i] <== is_substr4[i] * is_consecutive[i][2];
		reveal4[i] <== in[i+1] * is_reveal4[i];
	}
	signal is_substr5[msg_bytes];
	signal is_reveal5[msg_bytes];
	signal output reveal5[msg_bytes];
	for (var i = 0; i < msg_bytes; i++) {
		 // the 5-th substring transitions: [(85, 86), (86, 87), (86, 88), (87, 89), (88, 89), (89, 86)]
		is_substr5[i] <== MultiOR(6)([states[i+1][85] * states[i+2][86], states[i+1][86] * states[i+2][87], states[i+1][86] * states[i+2][88], states[i+1][87] * states[i+2][89], states[i+1][88] * states[i+2][89], states[i+1][89] * states[i+2][86]]);
		is_reveal5[i] <== is_substr5[i] * is_consecutive[i][2];
		reveal5[i] <== in[i+1] * is_reveal5[i];
	}
}