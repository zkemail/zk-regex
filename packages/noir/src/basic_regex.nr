
use crate::common::Sequence;


global table: [Field; 1280] = comptime { make_lookup_table() };

comptime fn make_lookup_table() -> [Field; 1280] {
    let mut table = [0; 1280];
        table[3 * 256 + 0] = 4;
    table[4 * 256 + 0] = 4;
    table[3 * 256 + 1] = 4;
    table[4 * 256 + 1] = 4;
    table[3 * 256 + 2] = 4;
    table[4 * 256 + 2] = 4;
    table[3 * 256 + 3] = 4;
    table[4 * 256 + 3] = 4;
    table[3 * 256 + 4] = 4;
    table[4 * 256 + 4] = 4;
    table[3 * 256 + 5] = 4;
    table[4 * 256 + 5] = 4;
    table[3 * 256 + 6] = 4;
    table[4 * 256 + 6] = 4;
    table[3 * 256 + 7] = 4;
    table[4 * 256 + 7] = 4;
    table[3 * 256 + 8] = 4;
    table[4 * 256 + 8] = 4;
    table[3 * 256 + 9] = 4;
    table[4 * 256 + 9] = 4;
    table[3 * 256 + 10] = 4;
    table[4 * 256 + 10] = 4;
    table[3 * 256 + 11] = 4;
    table[4 * 256 + 11] = 4;
    table[3 * 256 + 12] = 4;
    table[4 * 256 + 12] = 4;
    table[3 * 256 + 13] = 4;
    table[4 * 256 + 13] = 4;
    table[3 * 256 + 14] = 4;
    table[4 * 256 + 14] = 4;
    table[3 * 256 + 15] = 4;
    table[4 * 256 + 15] = 4;
    table[3 * 256 + 16] = 4;
    table[4 * 256 + 16] = 4;
    table[3 * 256 + 17] = 4;
    table[4 * 256 + 17] = 4;
    table[3 * 256 + 18] = 4;
    table[4 * 256 + 18] = 4;
    table[3 * 256 + 19] = 4;
    table[4 * 256 + 19] = 4;
    table[3 * 256 + 20] = 4;
    table[4 * 256 + 20] = 4;
    table[3 * 256 + 21] = 4;
    table[4 * 256 + 21] = 4;
    table[3 * 256 + 22] = 4;
    table[4 * 256 + 22] = 4;
    table[3 * 256 + 23] = 4;
    table[4 * 256 + 23] = 4;
    table[3 * 256 + 24] = 4;
    table[4 * 256 + 24] = 4;
    table[3 * 256 + 25] = 4;
    table[4 * 256 + 25] = 4;
    table[3 * 256 + 26] = 4;
    table[4 * 256 + 26] = 4;
    table[3 * 256 + 27] = 4;
    table[4 * 256 + 27] = 4;
    table[3 * 256 + 28] = 4;
    table[4 * 256 + 28] = 4;
    table[3 * 256 + 29] = 4;
    table[4 * 256 + 29] = 4;
    table[3 * 256 + 30] = 4;
    table[4 * 256 + 30] = 4;
    table[3 * 256 + 31] = 4;
    table[4 * 256 + 31] = 4;
    table[3 * 256 + 32] = 4;
    table[4 * 256 + 32] = 4;
    table[3 * 256 + 33] = 4;
    table[4 * 256 + 33] = 4;
    table[3 * 256 + 34] = 4;
    table[4 * 256 + 34] = 4;
    table[3 * 256 + 35] = 4;
    table[4 * 256 + 35] = 4;
    table[3 * 256 + 36] = 4;
    table[4 * 256 + 36] = 4;
    table[3 * 256 + 37] = 4;
    table[4 * 256 + 37] = 4;
    table[3 * 256 + 38] = 4;
    table[4 * 256 + 38] = 4;
    table[3 * 256 + 39] = 4;
    table[4 * 256 + 39] = 4;
    table[3 * 256 + 40] = 4;
    table[4 * 256 + 40] = 4;
    table[3 * 256 + 41] = 4;
    table[4 * 256 + 41] = 4;
    table[3 * 256 + 42] = 4;
    table[4 * 256 + 42] = 4;
    table[3 * 256 + 43] = 4;
    table[4 * 256 + 43] = 4;
    table[3 * 256 + 44] = 4;
    table[4 * 256 + 44] = 4;
    table[3 * 256 + 45] = 4;
    table[4 * 256 + 45] = 4;
    table[3 * 256 + 46] = 4;
    table[4 * 256 + 46] = 4;
    table[3 * 256 + 47] = 4;
    table[4 * 256 + 47] = 4;
    table[3 * 256 + 48] = 4;
    table[4 * 256 + 48] = 4;
    table[3 * 256 + 49] = 4;
    table[4 * 256 + 49] = 4;
    table[3 * 256 + 50] = 4;
    table[4 * 256 + 50] = 4;
    table[3 * 256 + 51] = 4;
    table[4 * 256 + 51] = 4;
    table[3 * 256 + 52] = 4;
    table[4 * 256 + 52] = 4;
    table[3 * 256 + 53] = 4;
    table[4 * 256 + 53] = 4;
    table[3 * 256 + 54] = 4;
    table[4 * 256 + 54] = 4;
    table[3 * 256 + 55] = 4;
    table[4 * 256 + 55] = 4;
    table[3 * 256 + 56] = 4;
    table[4 * 256 + 56] = 4;
    table[3 * 256 + 57] = 4;
    table[4 * 256 + 57] = 4;
    table[3 * 256 + 58] = 4;
    table[4 * 256 + 58] = 4;
    table[3 * 256 + 59] = 4;
    table[4 * 256 + 59] = 4;
    table[3 * 256 + 60] = 4;
    table[4 * 256 + 60] = 4;
    table[3 * 256 + 61] = 4;
    table[4 * 256 + 61] = 4;
    table[3 * 256 + 62] = 4;
    table[4 * 256 + 62] = 4;
    table[3 * 256 + 63] = 4;
    table[4 * 256 + 63] = 4;
    table[3 * 256 + 64] = 4;
    table[4 * 256 + 64] = 4;
    table[3 * 256 + 65] = 4;
    table[4 * 256 + 65] = 4;
    table[3 * 256 + 66] = 4;
    table[4 * 256 + 66] = 4;
    table[3 * 256 + 67] = 4;
    table[4 * 256 + 67] = 4;
    table[3 * 256 + 68] = 4;
    table[4 * 256 + 68] = 4;
    table[3 * 256 + 69] = 4;
    table[4 * 256 + 69] = 4;
    table[3 * 256 + 70] = 4;
    table[4 * 256 + 70] = 4;
    table[3 * 256 + 71] = 4;
    table[4 * 256 + 71] = 4;
    table[3 * 256 + 72] = 4;
    table[4 * 256 + 72] = 4;
    table[3 * 256 + 73] = 4;
    table[4 * 256 + 73] = 4;
    table[3 * 256 + 74] = 4;
    table[4 * 256 + 74] = 4;
    table[3 * 256 + 75] = 4;
    table[4 * 256 + 75] = 4;
    table[3 * 256 + 76] = 4;
    table[4 * 256 + 76] = 4;
    table[3 * 256 + 77] = 4;
    table[4 * 256 + 77] = 4;
    table[3 * 256 + 78] = 4;
    table[4 * 256 + 78] = 4;
    table[3 * 256 + 79] = 4;
    table[4 * 256 + 79] = 4;
    table[3 * 256 + 80] = 4;
    table[4 * 256 + 80] = 4;
    table[3 * 256 + 81] = 4;
    table[4 * 256 + 81] = 4;
    table[3 * 256 + 82] = 4;
    table[4 * 256 + 82] = 4;
    table[3 * 256 + 83] = 4;
    table[4 * 256 + 83] = 4;
    table[3 * 256 + 84] = 4;
    table[4 * 256 + 84] = 4;
    table[3 * 256 + 85] = 4;
    table[4 * 256 + 85] = 4;
    table[3 * 256 + 86] = 4;
    table[4 * 256 + 86] = 4;
    table[3 * 256 + 87] = 4;
    table[4 * 256 + 87] = 4;
    table[3 * 256 + 88] = 4;
    table[4 * 256 + 88] = 4;
    table[3 * 256 + 89] = 4;
    table[4 * 256 + 89] = 4;
    table[3 * 256 + 90] = 4;
    table[4 * 256 + 90] = 4;
    table[3 * 256 + 91] = 4;
    table[4 * 256 + 91] = 4;
    table[3 * 256 + 92] = 4;
    table[4 * 256 + 92] = 4;
    table[3 * 256 + 93] = 4;
    table[4 * 256 + 93] = 4;
    table[3 * 256 + 94] = 4;
    table[4 * 256 + 94] = 4;
    table[3 * 256 + 95] = 4;
    table[4 * 256 + 95] = 4;
    table[3 * 256 + 96] = 4;
    table[4 * 256 + 96] = 4;
    table[3 * 256 + 97] = 4;
    table[4 * 256 + 97] = 4;
    table[3 * 256 + 98] = 4;
    table[4 * 256 + 98] = 4;
    table[3 * 256 + 99] = 4;
    table[4 * 256 + 99] = 4;
    table[3 * 256 + 100] = 4;
    table[4 * 256 + 100] = 4;
    table[3 * 256 + 101] = 4;
    table[4 * 256 + 101] = 4;
    table[3 * 256 + 102] = 4;
    table[4 * 256 + 102] = 4;
    table[3 * 256 + 103] = 4;
    table[4 * 256 + 103] = 4;
    table[3 * 256 + 104] = 4;
    table[4 * 256 + 104] = 4;
    table[3 * 256 + 105] = 4;
    table[4 * 256 + 105] = 4;
    table[3 * 256 + 106] = 4;
    table[4 * 256 + 106] = 4;
    table[3 * 256 + 107] = 4;
    table[4 * 256 + 107] = 4;
    table[3 * 256 + 108] = 4;
    table[4 * 256 + 108] = 4;
    table[3 * 256 + 109] = 4;
    table[4 * 256 + 109] = 4;
    table[3 * 256 + 110] = 4;
    table[4 * 256 + 110] = 4;
    table[3 * 256 + 111] = 4;
    table[4 * 256 + 111] = 4;
    table[3 * 256 + 112] = 4;
    table[4 * 256 + 112] = 4;
    table[3 * 256 + 113] = 4;
    table[4 * 256 + 113] = 4;
    table[3 * 256 + 114] = 4;
    table[4 * 256 + 114] = 4;
    table[3 * 256 + 115] = 4;
    table[4 * 256 + 115] = 4;
    table[3 * 256 + 116] = 4;
    table[4 * 256 + 116] = 4;
    table[3 * 256 + 117] = 4;
    table[4 * 256 + 117] = 4;
    table[3 * 256 + 118] = 4;
    table[4 * 256 + 118] = 4;
    table[3 * 256 + 119] = 4;
    table[4 * 256 + 119] = 4;
    table[3 * 256 + 120] = 4;
    table[4 * 256 + 120] = 4;
    table[3 * 256 + 121] = 4;
    table[4 * 256 + 121] = 4;
    table[3 * 256 + 122] = 4;
    table[4 * 256 + 122] = 4;
    table[3 * 256 + 123] = 4;
    table[4 * 256 + 123] = 4;
    table[3 * 256 + 124] = 4;
    table[4 * 256 + 124] = 4;
    table[3 * 256 + 125] = 4;
    table[4 * 256 + 125] = 4;
    table[3 * 256 + 126] = 4;
    table[4 * 256 + 126] = 4;
    table[3 * 256 + 127] = 4;
    table[4 * 256 + 127] = 4;
    table[3 * 256 + 128] = 4;
    table[4 * 256 + 128] = 4;
    table[3 * 256 + 129] = 4;
    table[4 * 256 + 129] = 4;
    table[3 * 256 + 130] = 4;
    table[4 * 256 + 130] = 4;
    table[3 * 256 + 131] = 4;
    table[4 * 256 + 131] = 4;
    table[3 * 256 + 132] = 4;
    table[4 * 256 + 132] = 4;
    table[3 * 256 + 133] = 4;
    table[4 * 256 + 133] = 4;
    table[3 * 256 + 134] = 4;
    table[4 * 256 + 134] = 4;
    table[3 * 256 + 135] = 4;
    table[4 * 256 + 135] = 4;
    table[3 * 256 + 136] = 4;
    table[4 * 256 + 136] = 4;
    table[3 * 256 + 137] = 4;
    table[4 * 256 + 137] = 4;
    table[3 * 256 + 138] = 4;
    table[4 * 256 + 138] = 4;
    table[3 * 256 + 139] = 4;
    table[4 * 256 + 139] = 4;
    table[3 * 256 + 140] = 4;
    table[4 * 256 + 140] = 4;
    table[3 * 256 + 141] = 4;
    table[4 * 256 + 141] = 4;
    table[3 * 256 + 142] = 4;
    table[4 * 256 + 142] = 4;
    table[3 * 256 + 143] = 4;
    table[4 * 256 + 143] = 4;
    table[3 * 256 + 144] = 4;
    table[4 * 256 + 144] = 4;
    table[3 * 256 + 145] = 4;
    table[4 * 256 + 145] = 4;
    table[3 * 256 + 146] = 4;
    table[4 * 256 + 146] = 4;
    table[3 * 256 + 147] = 4;
    table[4 * 256 + 147] = 4;
    table[3 * 256 + 148] = 4;
    table[4 * 256 + 148] = 4;
    table[3 * 256 + 149] = 4;
    table[4 * 256 + 149] = 4;
    table[3 * 256 + 150] = 4;
    table[4 * 256 + 150] = 4;
    table[3 * 256 + 151] = 4;
    table[4 * 256 + 151] = 4;
    table[3 * 256 + 152] = 4;
    table[4 * 256 + 152] = 4;
    table[3 * 256 + 153] = 4;
    table[4 * 256 + 153] = 4;
    table[3 * 256 + 154] = 4;
    table[4 * 256 + 154] = 4;
    table[3 * 256 + 155] = 4;
    table[4 * 256 + 155] = 4;
    table[3 * 256 + 156] = 4;
    table[4 * 256 + 156] = 4;
    table[3 * 256 + 157] = 4;
    table[4 * 256 + 157] = 4;
    table[3 * 256 + 158] = 4;
    table[4 * 256 + 158] = 4;
    table[3 * 256 + 159] = 4;
    table[4 * 256 + 159] = 4;
    table[3 * 256 + 160] = 4;
    table[4 * 256 + 160] = 4;
    table[3 * 256 + 161] = 4;
    table[4 * 256 + 161] = 4;
    table[3 * 256 + 162] = 4;
    table[4 * 256 + 162] = 4;
    table[3 * 256 + 163] = 4;
    table[4 * 256 + 163] = 4;
    table[3 * 256 + 164] = 4;
    table[4 * 256 + 164] = 4;
    table[3 * 256 + 165] = 4;
    table[4 * 256 + 165] = 4;
    table[3 * 256 + 166] = 4;
    table[4 * 256 + 166] = 4;
    table[3 * 256 + 167] = 4;
    table[4 * 256 + 167] = 4;
    table[3 * 256 + 168] = 4;
    table[4 * 256 + 168] = 4;
    table[3 * 256 + 169] = 4;
    table[4 * 256 + 169] = 4;
    table[3 * 256 + 170] = 4;
    table[4 * 256 + 170] = 4;
    table[3 * 256 + 171] = 4;
    table[4 * 256 + 171] = 4;
    table[3 * 256 + 172] = 4;
    table[4 * 256 + 172] = 4;
    table[3 * 256 + 173] = 4;
    table[4 * 256 + 173] = 4;
    table[3 * 256 + 174] = 4;
    table[4 * 256 + 174] = 4;
    table[3 * 256 + 175] = 4;
    table[4 * 256 + 175] = 4;
    table[3 * 256 + 176] = 4;
    table[4 * 256 + 176] = 4;
    table[3 * 256 + 177] = 4;
    table[4 * 256 + 177] = 4;
    table[3 * 256 + 178] = 4;
    table[4 * 256 + 178] = 4;
    table[3 * 256 + 179] = 4;
    table[4 * 256 + 179] = 4;
    table[3 * 256 + 180] = 4;
    table[4 * 256 + 180] = 4;
    table[3 * 256 + 181] = 4;
    table[4 * 256 + 181] = 4;
    table[3 * 256 + 182] = 4;
    table[4 * 256 + 182] = 4;
    table[3 * 256 + 183] = 4;
    table[4 * 256 + 183] = 4;
    table[3 * 256 + 184] = 4;
    table[4 * 256 + 184] = 4;
    table[3 * 256 + 185] = 4;
    table[4 * 256 + 185] = 4;
    table[3 * 256 + 186] = 4;
    table[4 * 256 + 186] = 4;
    table[3 * 256 + 187] = 4;
    table[4 * 256 + 187] = 4;
    table[3 * 256 + 188] = 4;
    table[4 * 256 + 188] = 4;
    table[3 * 256 + 189] = 4;
    table[4 * 256 + 189] = 4;
    table[3 * 256 + 190] = 4;
    table[4 * 256 + 190] = 4;
    table[3 * 256 + 191] = 4;
    table[4 * 256 + 191] = 4;
    table[3 * 256 + 192] = 4;
    table[4 * 256 + 192] = 4;
    table[3 * 256 + 193] = 4;
    table[4 * 256 + 193] = 4;
    table[3 * 256 + 194] = 4;
    table[4 * 256 + 194] = 4;
    table[3 * 256 + 195] = 4;
    table[4 * 256 + 195] = 4;
    table[3 * 256 + 196] = 4;
    table[4 * 256 + 196] = 4;
    table[3 * 256 + 197] = 4;
    table[4 * 256 + 197] = 4;
    table[3 * 256 + 198] = 4;
    table[4 * 256 + 198] = 4;
    table[3 * 256 + 199] = 4;
    table[4 * 256 + 199] = 4;
    table[3 * 256 + 200] = 4;
    table[4 * 256 + 200] = 4;
    table[3 * 256 + 201] = 4;
    table[4 * 256 + 201] = 4;
    table[3 * 256 + 202] = 4;
    table[4 * 256 + 202] = 4;
    table[3 * 256 + 203] = 4;
    table[4 * 256 + 203] = 4;
    table[3 * 256 + 204] = 4;
    table[4 * 256 + 204] = 4;
    table[3 * 256 + 205] = 4;
    table[4 * 256 + 205] = 4;
    table[3 * 256 + 206] = 4;
    table[4 * 256 + 206] = 4;
    table[3 * 256 + 207] = 4;
    table[4 * 256 + 207] = 4;
    table[3 * 256 + 208] = 4;
    table[4 * 256 + 208] = 4;
    table[3 * 256 + 209] = 4;
    table[4 * 256 + 209] = 4;
    table[3 * 256 + 210] = 4;
    table[4 * 256 + 210] = 4;
    table[3 * 256 + 211] = 4;
    table[4 * 256 + 211] = 4;
    table[3 * 256 + 212] = 4;
    table[4 * 256 + 212] = 4;
    table[3 * 256 + 213] = 4;
    table[4 * 256 + 213] = 4;
    table[3 * 256 + 214] = 4;
    table[4 * 256 + 214] = 4;
    table[3 * 256 + 215] = 4;
    table[4 * 256 + 215] = 4;
    table[3 * 256 + 216] = 4;
    table[4 * 256 + 216] = 4;
    table[3 * 256 + 217] = 4;
    table[4 * 256 + 217] = 4;
    table[3 * 256 + 218] = 4;
    table[4 * 256 + 218] = 4;
    table[3 * 256 + 219] = 4;
    table[4 * 256 + 219] = 4;
    table[3 * 256 + 220] = 4;
    table[4 * 256 + 220] = 4;
    table[3 * 256 + 221] = 4;
    table[4 * 256 + 221] = 4;
    table[3 * 256 + 222] = 4;
    table[4 * 256 + 222] = 4;
    table[3 * 256 + 223] = 4;
    table[4 * 256 + 223] = 4;
    table[3 * 256 + 224] = 4;
    table[4 * 256 + 224] = 4;
    table[3 * 256 + 225] = 4;
    table[4 * 256 + 225] = 4;
    table[3 * 256 + 226] = 4;
    table[4 * 256 + 226] = 4;
    table[3 * 256 + 227] = 4;
    table[4 * 256 + 227] = 4;
    table[3 * 256 + 228] = 4;
    table[4 * 256 + 228] = 4;
    table[3 * 256 + 229] = 4;
    table[4 * 256 + 229] = 4;
    table[3 * 256 + 230] = 4;
    table[4 * 256 + 230] = 4;
    table[3 * 256 + 231] = 4;
    table[4 * 256 + 231] = 4;
    table[3 * 256 + 232] = 4;
    table[4 * 256 + 232] = 4;
    table[3 * 256 + 233] = 4;
    table[4 * 256 + 233] = 4;
    table[3 * 256 + 234] = 4;
    table[4 * 256 + 234] = 4;
    table[3 * 256 + 235] = 4;
    table[4 * 256 + 235] = 4;
    table[3 * 256 + 236] = 4;
    table[4 * 256 + 236] = 4;
    table[3 * 256 + 237] = 4;
    table[4 * 256 + 237] = 4;
    table[3 * 256 + 238] = 4;
    table[4 * 256 + 238] = 4;
    table[3 * 256 + 239] = 4;
    table[4 * 256 + 239] = 4;
    table[3 * 256 + 240] = 4;
    table[4 * 256 + 240] = 4;
    table[3 * 256 + 241] = 4;
    table[4 * 256 + 241] = 4;
    table[3 * 256 + 242] = 4;
    table[4 * 256 + 242] = 4;
    table[3 * 256 + 243] = 4;
    table[4 * 256 + 243] = 4;
    table[3 * 256 + 244] = 4;
    table[4 * 256 + 244] = 4;
    table[3 * 256 + 245] = 4;
    table[4 * 256 + 245] = 4;
    table[3 * 256 + 246] = 4;
    table[4 * 256 + 246] = 4;
    table[3 * 256 + 247] = 4;
    table[4 * 256 + 247] = 4;
    table[3 * 256 + 248] = 4;
    table[4 * 256 + 248] = 4;
    table[3 * 256 + 249] = 4;
    table[4 * 256 + 249] = 4;
    table[3 * 256 + 250] = 4;
    table[4 * 256 + 250] = 4;
    table[3 * 256 + 251] = 4;
    table[4 * 256 + 251] = 4;
    table[3 * 256 + 252] = 4;
    table[4 * 256 + 252] = 4;
    table[3 * 256 + 253] = 4;
    table[4 * 256 + 253] = 4;
    table[3 * 256 + 254] = 4;
    table[4 * 256 + 254] = 4;
    table[0 * 256 + 97] = 1;
    table[1 * 256 + 98] = 2;
    table[2 * 256 + 99] = 3;

    table
}


pub fn regex_match<let N: u32>(input: [u8; N]) -> (BoundedVec<Sequence, 3>, bool) {
    let substrings = unsafe { __regex_match(input) };
    
    // "Previous" state
    let mut s: Field = 0;
    s = table[255];
    // "Next"/upcoming state
    let mut s_next: Field = 0;
    let mut start_range = 0;
    let mut end_range = 0;

    // check the match
    for i in 0..N {
        // state transition
        let temp = input[i] as Field;
        s_next = table[s * 256 + temp];
        let potential_s_next = table[temp];
        if s_next == 0 {
            s = 0;
            s_next = potential_s_next;
        }
        std::as_witness(s_next);

        // range conditions for substring matches
        if ((start_range == 0) & (end_range == 0)) {
            start_range = i as Field;
        }
        if (((s == 3) & (s_next == 4)) & (end_range == 0)) {
            end_range = i as Field + 1;
        }
        

        let range_0 = substrings.get_unchecked(0).in_range(i);
        let case_0 = [
            (s_next == 1) & ((s == 0))
        ].any(|case| case == true) | !range_0;

        let range_1 = substrings.get_unchecked(1).in_range(i);
        let case_1 = [
            (s_next == 2) & ((s == 1))
        ].any(|case| case == true) | !range_1;

        let range_2 = substrings.get_unchecked(2).in_range(i);
        let case_2 = [
            (s_next == 3) & ((s == 2))
        ].any(|case| case == true) | !range_2;



        let substring_range_check = [case_0, case_1, case_2]
            .all(|case| case == true);
    
        assert(substring_range_check, "substr array ranges wrong");
                
    
        s = s_next;
    }
    // check final state
    
    let matched: bool = (s == 3) | (s == 4);
            
    // constrain extracted substrings to be in match range
    //let full_match = Sequence::new(start_range as u32, end_range as u32 - start_range as u32);
    //let full_match_end = full_match.end();
    // for i in 0..3 {
    //     let substring = substrings.get_unchecked(i);
    //     let is_not_valid = i >= substrings.len();
    //     let index_check = substring.index >= full_match.index;
    //     let length_check = substring.end() <= full_match_end;
    //     let check = (index_check) | is_not_valid;
    //     assert(check, f"Substring {i} range is out of bounds of the full match found");
    // }
    (substrings, matched)
}
    

pub unconstrained fn __regex_match<let N: u32>(input: [u8; N]) ->  BoundedVec<Sequence, 3> {
    // regex: abc
    let mut substrings: BoundedVec<Sequence, 3> = BoundedVec::new();
    let mut current_substring = Sequence::default();
    let mut full_match = Sequence::default();

    // "Previous" state
    let mut s: Field = 0;
    s = table[255];
    // "Next"/upcoming state
    let mut s_next: Field = 0;

    let mut consecutive_substr = 0;
    let mut complete = false;

    for i in 0..input.len() {
        let temp = input[i] as Field;
        let mut reset = false;
        s_next = table[s * 256 + temp];
        let potential_s_next = table[temp];
        if s_next == 0 {
            reset = true;
            s = 0;
            s_next = potential_s_next;
        }
        // If a substring was in the making, but the state was reset
        // we disregard previous progress because apparently it is invalid
        if (reset & (consecutive_substr == 1)) {
            current_substring = Sequence::default();
            consecutive_substr = 0;
        }
        // Fill up substrings


        if ((s == 0) & (s_next == 1)) {
    
            if (consecutive_substr == 0) {
                current_substring.index = i;
            };
            current_substring.length += 1;
            consecutive_substr = 1; 
        }

        else if ((s == 1) & (s_next == 2)) {
    
            current_substring.length += 1;
            consecutive_substr = 1; 
        }

        else if ((s == 2) & (s_next == 3)) {
    
            current_substring.length += 1;
            consecutive_substr = 1; 
        } else if ((consecutive_substr == 1) & (s_next == 0)) {
            current_substring = Sequence::default();
            full_match = Sequence::default();
            substrings = BoundedVec::new();
            consecutive_substr = 0;
        } else if (s == 3) & (s_next == 4) {
            full_match.length = i - full_match.index + 1;
            complete = true;
        } else if (consecutive_substr == 1) {
            // The substring is done so "save" it
            substrings.push(current_substring);
            // reset the substring holder for next use
            current_substring = Sequence::default();
            consecutive_substr = 0;
        }
        s = s_next;
        if complete == true {
            break;
        }
    }
    assert((s == 3) | (s == 4), f"no match: {s}");
    // Add pending substring that hasn't been added
    if consecutive_substr == 1 {
        substrings.push(current_substring);
        full_match.length = input.len() - full_match.index;
    }

    

    substrings
}
    
            
        
            