pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (?:\r\n|^)dkim-signature:(?:[a-z]+=[^;]+; )+bh=([a-zA-Z0-9+/=]+);
template BodyHashRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input captureGroup1Id[maxMatchBytes];
    signal input captureGroup1Start[maxMatchBytes];
    signal output isValid;

    var numStartStates = 3;
    var numAcceptStates = 1;
    var numTransitions = 66;
    var startStates[numStartStates] = [0, 1, 3];
    var acceptStates[numAcceptStates] = [35];

    signal isCurrentState[numTransitions][maxMatchBytes];
    signal isNextState[numTransitions][maxMatchBytes];
    signal isValidTransition[numTransitions][maxMatchBytes];
    signal reachedLastTransition[maxMatchBytes];
    signal isValidRegex[maxMatchBytes];
    signal isValidRegexTemp[maxMatchBytes];
    signal isWithinPathLength[maxMatchBytes];
    signal isWithinPathLengthMinusOne[maxMatchBytes-2];
    signal isTransitionLinked[maxMatchBytes];

    component isValidStartState;

    signal reachedAcceptState[maxMatchBytes];

    component isValidTraversal[maxMatchBytes];

    // Select the haystack from the input
    signal haystack[maxMatchBytes] <== SelectSubArray(maxHaystackBytes, maxMatchBytes)(inHaystack, matchStart, matchLength);

    // Check if the first state in the haystack is a valid start state
    isValidStartState = MultiOR(numStartStates);
    for (var i = 0; i < numStartStates; i++) {
        isValidStartState.in[i] <== IsEqual()([startStates[i], currStates[0]]);
    }
    isValidStartState.out === 1;

    for (var i = 0; i < maxMatchBytes; i++) {
        isWithinPathLength[i] <== LessThan(log2Ceil(maxMatchBytes))([i, matchLength]);

        // Check if the traversal is a valid path
        if (i < maxMatchBytes-2) {
            isWithinPathLengthMinusOne[i] <== LessThan(log2Ceil(maxMatchBytes))([i, matchLength-1]);
            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);
            isTransitionLinked[i] * isWithinPathLengthMinusOne[i] === isWithinPathLengthMinusOne[i];
        }

        // Transition 0: 0 -[13]-> 2 | Capture Group: []
        isValidTransition[0][i] <== CheckByteTransitionWithCapture(1)(0, 2, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 1: 0 -[100]-> 4 | Capture Group: []
        isValidTransition[1][i] <== CheckByteTransitionWithCapture(1)(0, 4, 100, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 2: 1 -[13]-> 2 | Capture Group: []
        isValidTransition[2][i] <== CheckByteTransitionWithCapture(1)(1, 2, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 3: 2 -[10]-> 3 | Capture Group: []
        isValidTransition[3][i] <== CheckByteTransitionWithCapture(1)(2, 3, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 4: 3 -[100]-> 4 | Capture Group: []
        isValidTransition[4][i] <== CheckByteTransitionWithCapture(1)(3, 4, 100, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 5: 4 -[107]-> 5 | Capture Group: []
        isValidTransition[5][i] <== CheckByteTransitionWithCapture(1)(4, 5, 107, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 6: 5 -[105]-> 6 | Capture Group: []
        isValidTransition[6][i] <== CheckByteTransitionWithCapture(1)(5, 6, 105, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 7: 6 -[109]-> 7 | Capture Group: []
        isValidTransition[7][i] <== CheckByteTransitionWithCapture(1)(6, 7, 109, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 8: 7 -[45]-> 8 | Capture Group: []
        isValidTransition[8][i] <== CheckByteTransitionWithCapture(1)(7, 8, 45, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 9: 8 -[115]-> 9 | Capture Group: []
        isValidTransition[9][i] <== CheckByteTransitionWithCapture(1)(8, 9, 115, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 10: 9 -[105]-> 10 | Capture Group: []
        isValidTransition[10][i] <== CheckByteTransitionWithCapture(1)(9, 10, 105, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 11: 10 -[103]-> 11 | Capture Group: []
        isValidTransition[11][i] <== CheckByteTransitionWithCapture(1)(10, 11, 103, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 12: 11 -[110]-> 12 | Capture Group: []
        isValidTransition[12][i] <== CheckByteTransitionWithCapture(1)(11, 12, 110, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 13: 12 -[97]-> 13 | Capture Group: []
        isValidTransition[13][i] <== CheckByteTransitionWithCapture(1)(12, 13, 97, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 14: 13 -[116]-> 14 | Capture Group: []
        isValidTransition[14][i] <== CheckByteTransitionWithCapture(1)(13, 14, 116, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 15: 14 -[117]-> 15 | Capture Group: []
        isValidTransition[15][i] <== CheckByteTransitionWithCapture(1)(14, 15, 117, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 16: 15 -[114]-> 16 | Capture Group: []
        isValidTransition[16][i] <== CheckByteTransitionWithCapture(1)(15, 16, 114, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 17: 16 -[101]-> 17 | Capture Group: []
        isValidTransition[17][i] <== CheckByteTransitionWithCapture(1)(16, 17, 101, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 18: 17 -[58]-> 18 | Capture Group: []
        isValidTransition[18][i] <== CheckByteTransitionWithCapture(1)(17, 18, 58, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 19: 18 -[97-122]-> 19 | Capture Group: []
        isValidTransition[19][i] <== CheckByteRangeTransitionWithCapture(1)(18, 19, 97, 122, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 20: 19 -[97-122]-> 19 | Capture Group: []
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture(1)(19, 19, 97, 122, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 21: 19 -[61]-> 27 | Capture Group: []
        isValidTransition[21][i] <== CheckByteTransitionWithCapture(1)(19, 27, 61, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 22: 20 -[128-191]-> 28 | Capture Group: []
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture(1)(20, 28, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 23: 21 -[160-191]-> 20 | Capture Group: []
        isValidTransition[23][i] <== CheckByteRangeTransitionWithCapture(1)(21, 20, 160, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 24: 22 -[128-191]-> 20 | Capture Group: []
        isValidTransition[24][i] <== CheckByteRangeTransitionWithCapture(1)(22, 20, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 25: 23 -[128-159]-> 20 | Capture Group: []
        isValidTransition[25][i] <== CheckByteRangeTransitionWithCapture(1)(23, 20, 128, 159, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 26: 24 -[144-191]-> 22 | Capture Group: []
        isValidTransition[26][i] <== CheckByteRangeTransitionWithCapture(1)(24, 22, 144, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 27: 25 -[128-191]-> 22 | Capture Group: []
        isValidTransition[27][i] <== CheckByteRangeTransitionWithCapture(1)(25, 22, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 28: 26 -[128-143]-> 22 | Capture Group: []
        isValidTransition[28][i] <== CheckByteRangeTransitionWithCapture(1)(26, 22, 128, 143, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 29: 27 -[194-223]-> 20 | Capture Group: []
        isValidTransition[29][i] <== CheckByteRangeTransitionWithCapture(1)(27, 20, 194, 223, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 30: 27 -[224]-> 21 | Capture Group: []
        isValidTransition[30][i] <== CheckByteTransitionWithCapture(1)(27, 21, 224, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 31: 27 -[225-236]-> 22 | Capture Group: []
        isValidTransition[31][i] <== CheckByteRangeTransitionWithCapture(1)(27, 22, 225, 236, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 32: 27 -[238-239]-> 22 | Capture Group: []
        isValidTransition[32][i] <== CheckByteRangeTransitionWithCapture(1)(27, 22, 238, 239, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 33: 27 -[237]-> 23 | Capture Group: []
        isValidTransition[33][i] <== CheckByteTransitionWithCapture(1)(27, 23, 237, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 34: 27 -[240]-> 24 | Capture Group: []
        isValidTransition[34][i] <== CheckByteTransitionWithCapture(1)(27, 24, 240, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 35: 27 -[241-243]-> 25 | Capture Group: []
        isValidTransition[35][i] <== CheckByteRangeTransitionWithCapture(1)(27, 25, 241, 243, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 36: 27 -[244]-> 26 | Capture Group: []
        isValidTransition[36][i] <== CheckByteTransitionWithCapture(1)(27, 26, 244, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 37: 27 -[0-58]-> 28 | Capture Group: []
        isValidTransition[37][i] <== CheckByteRangeTransitionWithCapture(1)(27, 28, 0, 58, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 38: 27 -[60-127]-> 28 | Capture Group: []
        isValidTransition[38][i] <== CheckByteRangeTransitionWithCapture(1)(27, 28, 60, 127, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 39: 28 -[194-223]-> 20 | Capture Group: []
        isValidTransition[39][i] <== CheckByteRangeTransitionWithCapture(1)(28, 20, 194, 223, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 40: 28 -[224]-> 21 | Capture Group: []
        isValidTransition[40][i] <== CheckByteTransitionWithCapture(1)(28, 21, 224, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 41: 28 -[225-236]-> 22 | Capture Group: []
        isValidTransition[41][i] <== CheckByteRangeTransitionWithCapture(1)(28, 22, 225, 236, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 42: 28 -[238-239]-> 22 | Capture Group: []
        isValidTransition[42][i] <== CheckByteRangeTransitionWithCapture(1)(28, 22, 238, 239, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 43: 28 -[237]-> 23 | Capture Group: []
        isValidTransition[43][i] <== CheckByteTransitionWithCapture(1)(28, 23, 237, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 44: 28 -[240]-> 24 | Capture Group: []
        isValidTransition[44][i] <== CheckByteTransitionWithCapture(1)(28, 24, 240, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 45: 28 -[241-243]-> 25 | Capture Group: []
        isValidTransition[45][i] <== CheckByteRangeTransitionWithCapture(1)(28, 25, 241, 243, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 46: 28 -[244]-> 26 | Capture Group: []
        isValidTransition[46][i] <== CheckByteTransitionWithCapture(1)(28, 26, 244, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 47: 28 -[0-58]-> 28 | Capture Group: []
        isValidTransition[47][i] <== CheckByteRangeTransitionWithCapture(1)(28, 28, 0, 58, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 48: 28 -[60-127]-> 28 | Capture Group: []
        isValidTransition[48][i] <== CheckByteRangeTransitionWithCapture(1)(28, 28, 60, 127, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 49: 28 -[59]-> 29 | Capture Group: []
        isValidTransition[49][i] <== CheckByteTransitionWithCapture(1)(28, 29, 59, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 50: 29 -[32]-> 30 | Capture Group: []
        isValidTransition[50][i] <== CheckByteTransitionWithCapture(1)(29, 30, 32, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 51: 30 -[97-122]-> 19 | Capture Group: []
        isValidTransition[51][i] <== CheckByteRangeTransitionWithCapture(1)(30, 19, 97, 122, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 52: 30 -[98]-> 31 | Capture Group: []
        isValidTransition[52][i] <== CheckByteTransitionWithCapture(1)(30, 31, 98, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 53: 31 -[104]-> 32 | Capture Group: []
        isValidTransition[53][i] <== CheckByteTransitionWithCapture(1)(31, 32, 104, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 54: 32 -[61]-> 33 | Capture Group: []
        isValidTransition[54][i] <== CheckByteTransitionWithCapture(1)(32, 33, 61, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 55: 33 -[43]-> 34 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[55][i] <== CheckByteTransitionWithCapture(1)(33, 34, 43, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 56: 33 -[47-57]-> 34 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[56][i] <== CheckByteRangeTransitionWithCapture(1)(33, 34, 47, 57, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 57: 33 -[61]-> 34 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[57][i] <== CheckByteTransitionWithCapture(1)(33, 34, 61, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 58: 33 -[65-90]-> 34 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[58][i] <== CheckByteRangeTransitionWithCapture(1)(33, 34, 65, 90, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 59: 33 -[97-122]-> 34 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[59][i] <== CheckByteRangeTransitionWithCapture(1)(33, 34, 97, 122, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 60: 34 -[43]-> 34 | Capture Group:[ (1, 0)]
        isValidTransition[60][i] <== CheckByteTransitionWithCapture(1)(34, 34, 43, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 61: 34 -[47-57]-> 34 | Capture Group:[ (1, 0)]
        isValidTransition[61][i] <== CheckByteRangeTransitionWithCapture(1)(34, 34, 47, 57, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 62: 34 -[61]-> 34 | Capture Group:[ (1, 0)]
        isValidTransition[62][i] <== CheckByteTransitionWithCapture(1)(34, 34, 61, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 63: 34 -[65-90]-> 34 | Capture Group:[ (1, 0)]
        isValidTransition[63][i] <== CheckByteRangeTransitionWithCapture(1)(34, 34, 65, 90, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 64: 34 -[97-122]-> 34 | Capture Group:[ (1, 0)]
        isValidTransition[64][i] <== CheckByteRangeTransitionWithCapture(1)(34, 34, 97, 122, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 65: 34 -[59]-> 35 | Capture Group: []
        isValidTransition[65][i] <== CheckByteTransitionWithCapture(1)(34, 35, 59, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);

        // Combine all valid transitions for this byte
        isValidTraversal[i] = MultiOR(numTransitions);
        for (var j = 0; j < numTransitions; j++) {
            isValidTraversal[i].in[j] <== isValidTransition[j][i];
        }
        isValidTraversal[i].out === isWithinPathLength[i];

        // Check if any accept state has been reached at the last transition
        reachedLastTransition[i] <== IsEqual()([i, matchLength-1]);
        reachedAcceptState[i] <== IsEqual()([nextStates[i], acceptStates[0]]);
        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i]);
        if (i == 0) {
            isValidRegex[i] <== isValidRegexTemp[i];
        } else {
            isValidRegex[i] <== isValidRegexTemp[i] + isValidRegex[i-1];
        }
    }

    isValid <== isValidRegex[maxMatchBytes-1];

    signal input captureGroupStartIndices[1];

    // Capture Group 1
    signal output capture1[44] <== CaptureSubstring(maxMatchBytes, 44, 1)(captureGroupStartIndices[0], haystack, captureGroup1Id, captureGroup1Start);
}
