
use crate::common::Sequence;


global table: [Field; 5120] = comptime { make_lookup_table() };

comptime fn make_lookup_table() -> [Field; 5120] {
    let mut table = [0; 5120];
        table[18 * 256 + 0] = 19;
    table[19 * 256 + 0] = 19;
    table[18 * 256 + 1] = 19;
    table[19 * 256 + 1] = 19;
    table[18 * 256 + 2] = 19;
    table[19 * 256 + 2] = 19;
    table[18 * 256 + 3] = 19;
    table[19 * 256 + 3] = 19;
    table[18 * 256 + 4] = 19;
    table[19 * 256 + 4] = 19;
    table[18 * 256 + 5] = 19;
    table[19 * 256 + 5] = 19;
    table[18 * 256 + 6] = 19;
    table[19 * 256 + 6] = 19;
    table[18 * 256 + 7] = 19;
    table[19 * 256 + 7] = 19;
    table[18 * 256 + 8] = 19;
    table[19 * 256 + 8] = 19;
    table[18 * 256 + 9] = 19;
    table[19 * 256 + 9] = 19;
    table[18 * 256 + 10] = 19;
    table[19 * 256 + 10] = 19;
    table[18 * 256 + 11] = 19;
    table[19 * 256 + 11] = 19;
    table[18 * 256 + 12] = 19;
    table[19 * 256 + 12] = 19;
    table[18 * 256 + 13] = 19;
    table[19 * 256 + 13] = 19;
    table[18 * 256 + 14] = 19;
    table[19 * 256 + 14] = 19;
    table[18 * 256 + 15] = 19;
    table[19 * 256 + 15] = 19;
    table[18 * 256 + 16] = 19;
    table[19 * 256 + 16] = 19;
    table[18 * 256 + 17] = 19;
    table[19 * 256 + 17] = 19;
    table[18 * 256 + 18] = 19;
    table[19 * 256 + 18] = 19;
    table[18 * 256 + 19] = 19;
    table[19 * 256 + 19] = 19;
    table[18 * 256 + 20] = 19;
    table[19 * 256 + 20] = 19;
    table[18 * 256 + 21] = 19;
    table[19 * 256 + 21] = 19;
    table[18 * 256 + 22] = 19;
    table[19 * 256 + 22] = 19;
    table[18 * 256 + 23] = 19;
    table[19 * 256 + 23] = 19;
    table[18 * 256 + 24] = 19;
    table[19 * 256 + 24] = 19;
    table[18 * 256 + 25] = 19;
    table[19 * 256 + 25] = 19;
    table[18 * 256 + 26] = 19;
    table[19 * 256 + 26] = 19;
    table[18 * 256 + 27] = 19;
    table[19 * 256 + 27] = 19;
    table[18 * 256 + 28] = 19;
    table[19 * 256 + 28] = 19;
    table[18 * 256 + 29] = 19;
    table[19 * 256 + 29] = 19;
    table[18 * 256 + 30] = 19;
    table[19 * 256 + 30] = 19;
    table[18 * 256 + 31] = 19;
    table[19 * 256 + 31] = 19;
    table[18 * 256 + 32] = 19;
    table[19 * 256 + 32] = 19;
    table[18 * 256 + 33] = 19;
    table[19 * 256 + 33] = 19;
    table[18 * 256 + 34] = 19;
    table[19 * 256 + 34] = 19;
    table[18 * 256 + 35] = 19;
    table[19 * 256 + 35] = 19;
    table[18 * 256 + 36] = 19;
    table[19 * 256 + 36] = 19;
    table[18 * 256 + 37] = 19;
    table[19 * 256 + 37] = 19;
    table[18 * 256 + 38] = 19;
    table[19 * 256 + 38] = 19;
    table[18 * 256 + 39] = 19;
    table[19 * 256 + 39] = 19;
    table[18 * 256 + 40] = 19;
    table[19 * 256 + 40] = 19;
    table[18 * 256 + 41] = 19;
    table[19 * 256 + 41] = 19;
    table[18 * 256 + 42] = 19;
    table[19 * 256 + 42] = 19;
    table[18 * 256 + 43] = 19;
    table[19 * 256 + 43] = 19;
    table[18 * 256 + 44] = 19;
    table[19 * 256 + 44] = 19;
    table[18 * 256 + 45] = 19;
    table[19 * 256 + 45] = 19;
    table[18 * 256 + 46] = 19;
    table[19 * 256 + 46] = 19;
    table[18 * 256 + 47] = 19;
    table[19 * 256 + 47] = 19;
    table[18 * 256 + 48] = 19;
    table[19 * 256 + 48] = 19;
    table[18 * 256 + 49] = 19;
    table[19 * 256 + 49] = 19;
    table[18 * 256 + 50] = 19;
    table[19 * 256 + 50] = 19;
    table[18 * 256 + 51] = 19;
    table[19 * 256 + 51] = 19;
    table[18 * 256 + 52] = 19;
    table[19 * 256 + 52] = 19;
    table[18 * 256 + 53] = 19;
    table[19 * 256 + 53] = 19;
    table[18 * 256 + 54] = 19;
    table[19 * 256 + 54] = 19;
    table[18 * 256 + 55] = 19;
    table[19 * 256 + 55] = 19;
    table[18 * 256 + 56] = 19;
    table[19 * 256 + 56] = 19;
    table[18 * 256 + 57] = 19;
    table[19 * 256 + 57] = 19;
    table[18 * 256 + 58] = 19;
    table[19 * 256 + 58] = 19;
    table[18 * 256 + 59] = 19;
    table[19 * 256 + 59] = 19;
    table[18 * 256 + 60] = 19;
    table[19 * 256 + 60] = 19;
    table[18 * 256 + 61] = 19;
    table[19 * 256 + 61] = 19;
    table[18 * 256 + 62] = 19;
    table[19 * 256 + 62] = 19;
    table[18 * 256 + 63] = 19;
    table[19 * 256 + 63] = 19;
    table[18 * 256 + 64] = 19;
    table[19 * 256 + 64] = 19;
    table[18 * 256 + 65] = 19;
    table[19 * 256 + 65] = 19;
    table[18 * 256 + 66] = 19;
    table[19 * 256 + 66] = 19;
    table[18 * 256 + 67] = 19;
    table[19 * 256 + 67] = 19;
    table[18 * 256 + 68] = 19;
    table[19 * 256 + 68] = 19;
    table[18 * 256 + 69] = 19;
    table[19 * 256 + 69] = 19;
    table[18 * 256 + 70] = 19;
    table[19 * 256 + 70] = 19;
    table[18 * 256 + 71] = 19;
    table[19 * 256 + 71] = 19;
    table[18 * 256 + 72] = 19;
    table[19 * 256 + 72] = 19;
    table[18 * 256 + 73] = 19;
    table[19 * 256 + 73] = 19;
    table[18 * 256 + 74] = 19;
    table[19 * 256 + 74] = 19;
    table[18 * 256 + 75] = 19;
    table[19 * 256 + 75] = 19;
    table[18 * 256 + 76] = 19;
    table[19 * 256 + 76] = 19;
    table[18 * 256 + 77] = 19;
    table[19 * 256 + 77] = 19;
    table[18 * 256 + 78] = 19;
    table[19 * 256 + 78] = 19;
    table[18 * 256 + 79] = 19;
    table[19 * 256 + 79] = 19;
    table[18 * 256 + 80] = 19;
    table[19 * 256 + 80] = 19;
    table[18 * 256 + 81] = 19;
    table[19 * 256 + 81] = 19;
    table[18 * 256 + 82] = 19;
    table[19 * 256 + 82] = 19;
    table[18 * 256 + 83] = 19;
    table[19 * 256 + 83] = 19;
    table[18 * 256 + 84] = 19;
    table[19 * 256 + 84] = 19;
    table[18 * 256 + 85] = 19;
    table[19 * 256 + 85] = 19;
    table[18 * 256 + 86] = 19;
    table[19 * 256 + 86] = 19;
    table[18 * 256 + 87] = 19;
    table[19 * 256 + 87] = 19;
    table[18 * 256 + 88] = 19;
    table[19 * 256 + 88] = 19;
    table[18 * 256 + 89] = 19;
    table[19 * 256 + 89] = 19;
    table[18 * 256 + 90] = 19;
    table[19 * 256 + 90] = 19;
    table[18 * 256 + 91] = 19;
    table[19 * 256 + 91] = 19;
    table[18 * 256 + 92] = 19;
    table[19 * 256 + 92] = 19;
    table[18 * 256 + 93] = 19;
    table[19 * 256 + 93] = 19;
    table[18 * 256 + 94] = 19;
    table[19 * 256 + 94] = 19;
    table[18 * 256 + 95] = 19;
    table[19 * 256 + 95] = 19;
    table[18 * 256 + 96] = 19;
    table[19 * 256 + 96] = 19;
    table[18 * 256 + 97] = 19;
    table[19 * 256 + 97] = 19;
    table[18 * 256 + 98] = 19;
    table[19 * 256 + 98] = 19;
    table[18 * 256 + 99] = 19;
    table[19 * 256 + 99] = 19;
    table[18 * 256 + 100] = 19;
    table[19 * 256 + 100] = 19;
    table[18 * 256 + 101] = 19;
    table[19 * 256 + 101] = 19;
    table[18 * 256 + 102] = 19;
    table[19 * 256 + 102] = 19;
    table[18 * 256 + 103] = 19;
    table[19 * 256 + 103] = 19;
    table[18 * 256 + 104] = 19;
    table[19 * 256 + 104] = 19;
    table[18 * 256 + 105] = 19;
    table[19 * 256 + 105] = 19;
    table[18 * 256 + 106] = 19;
    table[19 * 256 + 106] = 19;
    table[18 * 256 + 107] = 19;
    table[19 * 256 + 107] = 19;
    table[18 * 256 + 108] = 19;
    table[19 * 256 + 108] = 19;
    table[18 * 256 + 109] = 19;
    table[19 * 256 + 109] = 19;
    table[18 * 256 + 110] = 19;
    table[19 * 256 + 110] = 19;
    table[18 * 256 + 111] = 19;
    table[19 * 256 + 111] = 19;
    table[18 * 256 + 112] = 19;
    table[19 * 256 + 112] = 19;
    table[18 * 256 + 113] = 19;
    table[19 * 256 + 113] = 19;
    table[18 * 256 + 114] = 19;
    table[19 * 256 + 114] = 19;
    table[18 * 256 + 115] = 19;
    table[19 * 256 + 115] = 19;
    table[18 * 256 + 116] = 19;
    table[19 * 256 + 116] = 19;
    table[18 * 256 + 117] = 19;
    table[19 * 256 + 117] = 19;
    table[18 * 256 + 118] = 19;
    table[19 * 256 + 118] = 19;
    table[18 * 256 + 119] = 19;
    table[19 * 256 + 119] = 19;
    table[18 * 256 + 120] = 19;
    table[19 * 256 + 120] = 19;
    table[18 * 256 + 121] = 19;
    table[19 * 256 + 121] = 19;
    table[18 * 256 + 122] = 19;
    table[19 * 256 + 122] = 19;
    table[18 * 256 + 123] = 19;
    table[19 * 256 + 123] = 19;
    table[18 * 256 + 124] = 19;
    table[19 * 256 + 124] = 19;
    table[18 * 256 + 125] = 19;
    table[19 * 256 + 125] = 19;
    table[18 * 256 + 126] = 19;
    table[19 * 256 + 126] = 19;
    table[18 * 256 + 127] = 19;
    table[19 * 256 + 127] = 19;
    table[18 * 256 + 128] = 19;
    table[19 * 256 + 128] = 19;
    table[18 * 256 + 129] = 19;
    table[19 * 256 + 129] = 19;
    table[18 * 256 + 130] = 19;
    table[19 * 256 + 130] = 19;
    table[18 * 256 + 131] = 19;
    table[19 * 256 + 131] = 19;
    table[18 * 256 + 132] = 19;
    table[19 * 256 + 132] = 19;
    table[18 * 256 + 133] = 19;
    table[19 * 256 + 133] = 19;
    table[18 * 256 + 134] = 19;
    table[19 * 256 + 134] = 19;
    table[18 * 256 + 135] = 19;
    table[19 * 256 + 135] = 19;
    table[18 * 256 + 136] = 19;
    table[19 * 256 + 136] = 19;
    table[18 * 256 + 137] = 19;
    table[19 * 256 + 137] = 19;
    table[18 * 256 + 138] = 19;
    table[19 * 256 + 138] = 19;
    table[18 * 256 + 139] = 19;
    table[19 * 256 + 139] = 19;
    table[18 * 256 + 140] = 19;
    table[19 * 256 + 140] = 19;
    table[18 * 256 + 141] = 19;
    table[19 * 256 + 141] = 19;
    table[18 * 256 + 142] = 19;
    table[19 * 256 + 142] = 19;
    table[18 * 256 + 143] = 19;
    table[19 * 256 + 143] = 19;
    table[18 * 256 + 144] = 19;
    table[19 * 256 + 144] = 19;
    table[18 * 256 + 145] = 19;
    table[19 * 256 + 145] = 19;
    table[18 * 256 + 146] = 19;
    table[19 * 256 + 146] = 19;
    table[18 * 256 + 147] = 19;
    table[19 * 256 + 147] = 19;
    table[18 * 256 + 148] = 19;
    table[19 * 256 + 148] = 19;
    table[18 * 256 + 149] = 19;
    table[19 * 256 + 149] = 19;
    table[18 * 256 + 150] = 19;
    table[19 * 256 + 150] = 19;
    table[18 * 256 + 151] = 19;
    table[19 * 256 + 151] = 19;
    table[18 * 256 + 152] = 19;
    table[19 * 256 + 152] = 19;
    table[18 * 256 + 153] = 19;
    table[19 * 256 + 153] = 19;
    table[18 * 256 + 154] = 19;
    table[19 * 256 + 154] = 19;
    table[18 * 256 + 155] = 19;
    table[19 * 256 + 155] = 19;
    table[18 * 256 + 156] = 19;
    table[19 * 256 + 156] = 19;
    table[18 * 256 + 157] = 19;
    table[19 * 256 + 157] = 19;
    table[18 * 256 + 158] = 19;
    table[19 * 256 + 158] = 19;
    table[18 * 256 + 159] = 19;
    table[19 * 256 + 159] = 19;
    table[18 * 256 + 160] = 19;
    table[19 * 256 + 160] = 19;
    table[18 * 256 + 161] = 19;
    table[19 * 256 + 161] = 19;
    table[18 * 256 + 162] = 19;
    table[19 * 256 + 162] = 19;
    table[18 * 256 + 163] = 19;
    table[19 * 256 + 163] = 19;
    table[18 * 256 + 164] = 19;
    table[19 * 256 + 164] = 19;
    table[18 * 256 + 165] = 19;
    table[19 * 256 + 165] = 19;
    table[18 * 256 + 166] = 19;
    table[19 * 256 + 166] = 19;
    table[18 * 256 + 167] = 19;
    table[19 * 256 + 167] = 19;
    table[18 * 256 + 168] = 19;
    table[19 * 256 + 168] = 19;
    table[18 * 256 + 169] = 19;
    table[19 * 256 + 169] = 19;
    table[18 * 256 + 170] = 19;
    table[19 * 256 + 170] = 19;
    table[18 * 256 + 171] = 19;
    table[19 * 256 + 171] = 19;
    table[18 * 256 + 172] = 19;
    table[19 * 256 + 172] = 19;
    table[18 * 256 + 173] = 19;
    table[19 * 256 + 173] = 19;
    table[18 * 256 + 174] = 19;
    table[19 * 256 + 174] = 19;
    table[18 * 256 + 175] = 19;
    table[19 * 256 + 175] = 19;
    table[18 * 256 + 176] = 19;
    table[19 * 256 + 176] = 19;
    table[18 * 256 + 177] = 19;
    table[19 * 256 + 177] = 19;
    table[18 * 256 + 178] = 19;
    table[19 * 256 + 178] = 19;
    table[18 * 256 + 179] = 19;
    table[19 * 256 + 179] = 19;
    table[18 * 256 + 180] = 19;
    table[19 * 256 + 180] = 19;
    table[18 * 256 + 181] = 19;
    table[19 * 256 + 181] = 19;
    table[18 * 256 + 182] = 19;
    table[19 * 256 + 182] = 19;
    table[18 * 256 + 183] = 19;
    table[19 * 256 + 183] = 19;
    table[18 * 256 + 184] = 19;
    table[19 * 256 + 184] = 19;
    table[18 * 256 + 185] = 19;
    table[19 * 256 + 185] = 19;
    table[18 * 256 + 186] = 19;
    table[19 * 256 + 186] = 19;
    table[18 * 256 + 187] = 19;
    table[19 * 256 + 187] = 19;
    table[18 * 256 + 188] = 19;
    table[19 * 256 + 188] = 19;
    table[18 * 256 + 189] = 19;
    table[19 * 256 + 189] = 19;
    table[18 * 256 + 190] = 19;
    table[19 * 256 + 190] = 19;
    table[18 * 256 + 191] = 19;
    table[19 * 256 + 191] = 19;
    table[18 * 256 + 192] = 19;
    table[19 * 256 + 192] = 19;
    table[18 * 256 + 193] = 19;
    table[19 * 256 + 193] = 19;
    table[18 * 256 + 194] = 19;
    table[19 * 256 + 194] = 19;
    table[18 * 256 + 195] = 19;
    table[19 * 256 + 195] = 19;
    table[18 * 256 + 196] = 19;
    table[19 * 256 + 196] = 19;
    table[18 * 256 + 197] = 19;
    table[19 * 256 + 197] = 19;
    table[18 * 256 + 198] = 19;
    table[19 * 256 + 198] = 19;
    table[18 * 256 + 199] = 19;
    table[19 * 256 + 199] = 19;
    table[18 * 256 + 200] = 19;
    table[19 * 256 + 200] = 19;
    table[18 * 256 + 201] = 19;
    table[19 * 256 + 201] = 19;
    table[18 * 256 + 202] = 19;
    table[19 * 256 + 202] = 19;
    table[18 * 256 + 203] = 19;
    table[19 * 256 + 203] = 19;
    table[18 * 256 + 204] = 19;
    table[19 * 256 + 204] = 19;
    table[18 * 256 + 205] = 19;
    table[19 * 256 + 205] = 19;
    table[18 * 256 + 206] = 19;
    table[19 * 256 + 206] = 19;
    table[18 * 256 + 207] = 19;
    table[19 * 256 + 207] = 19;
    table[18 * 256 + 208] = 19;
    table[19 * 256 + 208] = 19;
    table[18 * 256 + 209] = 19;
    table[19 * 256 + 209] = 19;
    table[18 * 256 + 210] = 19;
    table[19 * 256 + 210] = 19;
    table[18 * 256 + 211] = 19;
    table[19 * 256 + 211] = 19;
    table[18 * 256 + 212] = 19;
    table[19 * 256 + 212] = 19;
    table[18 * 256 + 213] = 19;
    table[19 * 256 + 213] = 19;
    table[18 * 256 + 214] = 19;
    table[19 * 256 + 214] = 19;
    table[18 * 256 + 215] = 19;
    table[19 * 256 + 215] = 19;
    table[18 * 256 + 216] = 19;
    table[19 * 256 + 216] = 19;
    table[18 * 256 + 217] = 19;
    table[19 * 256 + 217] = 19;
    table[18 * 256 + 218] = 19;
    table[19 * 256 + 218] = 19;
    table[18 * 256 + 219] = 19;
    table[19 * 256 + 219] = 19;
    table[18 * 256 + 220] = 19;
    table[19 * 256 + 220] = 19;
    table[18 * 256 + 221] = 19;
    table[19 * 256 + 221] = 19;
    table[18 * 256 + 222] = 19;
    table[19 * 256 + 222] = 19;
    table[18 * 256 + 223] = 19;
    table[19 * 256 + 223] = 19;
    table[18 * 256 + 224] = 19;
    table[19 * 256 + 224] = 19;
    table[18 * 256 + 225] = 19;
    table[19 * 256 + 225] = 19;
    table[18 * 256 + 226] = 19;
    table[19 * 256 + 226] = 19;
    table[18 * 256 + 227] = 19;
    table[19 * 256 + 227] = 19;
    table[18 * 256 + 228] = 19;
    table[19 * 256 + 228] = 19;
    table[18 * 256 + 229] = 19;
    table[19 * 256 + 229] = 19;
    table[18 * 256 + 230] = 19;
    table[19 * 256 + 230] = 19;
    table[18 * 256 + 231] = 19;
    table[19 * 256 + 231] = 19;
    table[18 * 256 + 232] = 19;
    table[19 * 256 + 232] = 19;
    table[18 * 256 + 233] = 19;
    table[19 * 256 + 233] = 19;
    table[18 * 256 + 234] = 19;
    table[19 * 256 + 234] = 19;
    table[18 * 256 + 235] = 19;
    table[19 * 256 + 235] = 19;
    table[18 * 256 + 236] = 19;
    table[19 * 256 + 236] = 19;
    table[18 * 256 + 237] = 19;
    table[19 * 256 + 237] = 19;
    table[18 * 256 + 238] = 19;
    table[19 * 256 + 238] = 19;
    table[18 * 256 + 239] = 19;
    table[19 * 256 + 239] = 19;
    table[18 * 256 + 240] = 19;
    table[19 * 256 + 240] = 19;
    table[18 * 256 + 241] = 19;
    table[19 * 256 + 241] = 19;
    table[18 * 256 + 242] = 19;
    table[19 * 256 + 242] = 19;
    table[18 * 256 + 243] = 19;
    table[19 * 256 + 243] = 19;
    table[18 * 256 + 244] = 19;
    table[19 * 256 + 244] = 19;
    table[18 * 256 + 245] = 19;
    table[19 * 256 + 245] = 19;
    table[18 * 256 + 246] = 19;
    table[19 * 256 + 246] = 19;
    table[18 * 256 + 247] = 19;
    table[19 * 256 + 247] = 19;
    table[18 * 256 + 248] = 19;
    table[19 * 256 + 248] = 19;
    table[18 * 256 + 249] = 19;
    table[19 * 256 + 249] = 19;
    table[18 * 256 + 250] = 19;
    table[19 * 256 + 250] = 19;
    table[18 * 256 + 251] = 19;
    table[19 * 256 + 251] = 19;
    table[18 * 256 + 252] = 19;
    table[19 * 256 + 252] = 19;
    table[18 * 256 + 253] = 19;
    table[19 * 256 + 253] = 19;
    table[18 * 256 + 254] = 19;
    table[19 * 256 + 254] = 19;
    table[0 * 256 + 13] = 1;
    table[0 * 256 + 255] = 2;
    table[1 * 256 + 10] = 2;
    table[2 * 256 + 109] = 3;
    table[3 * 256 + 101] = 4;
    table[4 * 256 + 115] = 5;
    table[5 * 256 + 115] = 6;
    table[6 * 256 + 97] = 7;
    table[7 * 256 + 103] = 8;
    table[8 * 256 + 101] = 9;
    table[9 * 256 + 45] = 10;
    table[10 * 256 + 105] = 11;
    table[11 * 256 + 100] = 12;
    table[12 * 256 + 58] = 13;
    table[13 * 256 + 60] = 14;
    table[14 * 256 + 43] = 15;
    table[14 * 256 + 45] = 15;
    table[14 * 256 + 46] = 15;
    table[14 * 256 + 48] = 15;
    table[14 * 256 + 49] = 15;
    table[14 * 256 + 50] = 15;
    table[14 * 256 + 51] = 15;
    table[14 * 256 + 52] = 15;
    table[14 * 256 + 53] = 15;
    table[14 * 256 + 54] = 15;
    table[14 * 256 + 55] = 15;
    table[14 * 256 + 56] = 15;
    table[14 * 256 + 57] = 15;
    table[14 * 256 + 61] = 15;
    table[14 * 256 + 64] = 15;
    table[14 * 256 + 65] = 15;
    table[14 * 256 + 66] = 15;
    table[14 * 256 + 67] = 15;
    table[14 * 256 + 68] = 15;
    table[14 * 256 + 69] = 15;
    table[14 * 256 + 70] = 15;
    table[14 * 256 + 71] = 15;
    table[14 * 256 + 72] = 15;
    table[14 * 256 + 73] = 15;
    table[14 * 256 + 74] = 15;
    table[14 * 256 + 75] = 15;
    table[14 * 256 + 76] = 15;
    table[14 * 256 + 77] = 15;
    table[14 * 256 + 78] = 15;
    table[14 * 256 + 79] = 15;
    table[14 * 256 + 80] = 15;
    table[14 * 256 + 81] = 15;
    table[14 * 256 + 82] = 15;
    table[14 * 256 + 83] = 15;
    table[14 * 256 + 84] = 15;
    table[14 * 256 + 85] = 15;
    table[14 * 256 + 86] = 15;
    table[14 * 256 + 87] = 15;
    table[14 * 256 + 88] = 15;
    table[14 * 256 + 89] = 15;
    table[14 * 256 + 90] = 15;
    table[14 * 256 + 95] = 15;
    table[14 * 256 + 97] = 15;
    table[14 * 256 + 98] = 15;
    table[14 * 256 + 99] = 15;
    table[14 * 256 + 100] = 15;
    table[14 * 256 + 101] = 15;
    table[14 * 256 + 102] = 15;
    table[14 * 256 + 103] = 15;
    table[14 * 256 + 104] = 15;
    table[14 * 256 + 105] = 15;
    table[14 * 256 + 106] = 15;
    table[14 * 256 + 107] = 15;
    table[14 * 256 + 108] = 15;
    table[14 * 256 + 109] = 15;
    table[14 * 256 + 110] = 15;
    table[14 * 256 + 111] = 15;
    table[14 * 256 + 112] = 15;
    table[14 * 256 + 113] = 15;
    table[14 * 256 + 114] = 15;
    table[14 * 256 + 115] = 15;
    table[14 * 256 + 116] = 15;
    table[14 * 256 + 117] = 15;
    table[14 * 256 + 118] = 15;
    table[14 * 256 + 119] = 15;
    table[14 * 256 + 120] = 15;
    table[14 * 256 + 121] = 15;
    table[14 * 256 + 122] = 15;
    table[15 * 256 + 43] = 15;
    table[15 * 256 + 45] = 15;
    table[15 * 256 + 46] = 15;
    table[15 * 256 + 48] = 15;
    table[15 * 256 + 49] = 15;
    table[15 * 256 + 50] = 15;
    table[15 * 256 + 51] = 15;
    table[15 * 256 + 52] = 15;
    table[15 * 256 + 53] = 15;
    table[15 * 256 + 54] = 15;
    table[15 * 256 + 55] = 15;
    table[15 * 256 + 56] = 15;
    table[15 * 256 + 57] = 15;
    table[15 * 256 + 61] = 15;
    table[15 * 256 + 64] = 15;
    table[15 * 256 + 65] = 15;
    table[15 * 256 + 66] = 15;
    table[15 * 256 + 67] = 15;
    table[15 * 256 + 68] = 15;
    table[15 * 256 + 69] = 15;
    table[15 * 256 + 70] = 15;
    table[15 * 256 + 71] = 15;
    table[15 * 256 + 72] = 15;
    table[15 * 256 + 73] = 15;
    table[15 * 256 + 74] = 15;
    table[15 * 256 + 75] = 15;
    table[15 * 256 + 76] = 15;
    table[15 * 256 + 77] = 15;
    table[15 * 256 + 78] = 15;
    table[15 * 256 + 79] = 15;
    table[15 * 256 + 80] = 15;
    table[15 * 256 + 81] = 15;
    table[15 * 256 + 82] = 15;
    table[15 * 256 + 83] = 15;
    table[15 * 256 + 84] = 15;
    table[15 * 256 + 85] = 15;
    table[15 * 256 + 86] = 15;
    table[15 * 256 + 87] = 15;
    table[15 * 256 + 88] = 15;
    table[15 * 256 + 89] = 15;
    table[15 * 256 + 90] = 15;
    table[15 * 256 + 95] = 15;
    table[15 * 256 + 97] = 15;
    table[15 * 256 + 98] = 15;
    table[15 * 256 + 99] = 15;
    table[15 * 256 + 100] = 15;
    table[15 * 256 + 101] = 15;
    table[15 * 256 + 102] = 15;
    table[15 * 256 + 103] = 15;
    table[15 * 256 + 104] = 15;
    table[15 * 256 + 105] = 15;
    table[15 * 256 + 106] = 15;
    table[15 * 256 + 107] = 15;
    table[15 * 256 + 108] = 15;
    table[15 * 256 + 109] = 15;
    table[15 * 256 + 110] = 15;
    table[15 * 256 + 111] = 15;
    table[15 * 256 + 112] = 15;
    table[15 * 256 + 113] = 15;
    table[15 * 256 + 114] = 15;
    table[15 * 256 + 115] = 15;
    table[15 * 256 + 116] = 15;
    table[15 * 256 + 117] = 15;
    table[15 * 256 + 118] = 15;
    table[15 * 256 + 119] = 15;
    table[15 * 256 + 120] = 15;
    table[15 * 256 + 121] = 15;
    table[15 * 256 + 122] = 15;
    table[15 * 256 + 62] = 16;
    table[16 * 256 + 13] = 17;
    table[17 * 256 + 10] = 18;

    table
}


pub fn regex_match<let N: u32>(input: [u8; N]) -> (BoundedVec<Sequence, 1>, bool) {
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
        if (((s == 18) & (s_next == 19)) & (end_range == 0)) {
            end_range = i as Field + 1;
        }
        

        let range_0 = substrings.get_unchecked(0).in_range(i);
        let case_0 = [
            (s_next == 14) & ((s == 13)),
        	(s == 15) & ((s_next == 15) | (s_next == 16)),
        	(s_next == 15) & ((s == 14))
        ].any(|case| case == true) | !range_0;



        let substring_range_check = [case_0]
            .all(|case| case == true);
    
        assert(substring_range_check, "substr array ranges wrong");
                
    
        s = s_next;
    }
    // check final state
    
    let matched: bool = (s == 18) | (s == 19);
            
    // constrain extracted substrings to be in match range
    //let full_match = Sequence::new(start_range as u32, end_range as u32 - start_range as u32);
    //let full_match_end = full_match.end();
    // for i in 0..1 {
    //     let substring = substrings.get_unchecked(i);
    //     let is_not_valid = i >= substrings.len();
    //     let index_check = substring.index >= full_match.index;
    //     let length_check = substring.end() <= full_match_end;
    //     let check = (index_check) | is_not_valid;
    //     assert(check, f"Substring {i} range is out of bounds of the full match found");
    // }
    (substrings, matched)
}
    

pub unconstrained fn __regex_match<let N: u32>(input: [u8; N]) ->  BoundedVec<Sequence, 1> {
    // regex: (\r\n|^)message-id:<[A-Za-z0-9=@\.\+_-]+>\r\n
    let mut substrings: BoundedVec<Sequence, 1> = BoundedVec::new();
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


        if ((s == 13) & (s_next == 14) | (s == 14) & (s_next == 15) | (s == 15) & (s_next == 15) | (s == 15) & (s_next == 16)) {
    
            if (consecutive_substr == 0) {
                current_substring.index = i;
            };
            current_substring.length += 1;
            consecutive_substr = 1; 
        } else if ((consecutive_substr == 1) & (s_next == 0)) {
            current_substring = Sequence::default();
            full_match = Sequence::default();
            substrings = BoundedVec::new();
            consecutive_substr = 0;
        } else if (s == 18) & (s_next == 19) {
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
    assert((s == 18) | (s == 19), f"no match: {s}");
    // Add pending substring that hasn't been added
    if consecutive_substr == 1 {
        substrings.push(current_substring);
        full_match.length = input.len() - full_match.index;
    }

    

    substrings
}
    
            
        
            