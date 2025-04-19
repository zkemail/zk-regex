pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";
include "@zk-email/circuits/utils/array.circom";

// regex: (?:\r\n|^)dkim-signature:(?:[a-z]+=[^;]+; )+bh=([a-zA-Z0-9+/=]+);
template BodyHashRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input captureGroupIds[maxMatchBytes];
    signal input captureGroupStarts[maxMatchBytes];

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
            isTransitionLinked[i] === isWithinPathLengthMinusOne[i];
        }

        // Transition 0: 21 -[160-191]-> 20 | Capture Group: (0, 0)
        isValidTransition[0][i] <== CheckByteRangeTransitionWithCapture()(21, 20, 160, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 1: 25 -[128-191]-> 22 | Capture Group: (0, 0)
        isValidTransition[1][i] <== CheckByteRangeTransitionWithCapture()(25, 22, 128, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 2: 28 -[224]-> 21 | Capture Group: (0, 0)
        isValidTransition[2][i] <== CheckByteTransitionWithCapture()(28, 21, 224, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 3: 28 -[237]-> 23 | Capture Group: (0, 0)
        isValidTransition[3][i] <== CheckByteTransitionWithCapture()(28, 23, 237, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 4: 28 -[241-243]-> 25 | Capture Group: (0, 0)
        isValidTransition[4][i] <== CheckByteRangeTransitionWithCapture()(28, 25, 241, 243, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 5: 18 -[97-122]-> 19 | Capture Group: (0, 0)
        isValidTransition[5][i] <== CheckByteRangeTransitionWithCapture()(18, 19, 97, 122, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 6: 28 -[59]-> 29 | Capture Group: (0, 0)
        isValidTransition[6][i] <== CheckByteTransitionWithCapture()(28, 29, 59, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 7: 1 -[13]-> 2 | Capture Group: (0, 0)
        isValidTransition[7][i] <== CheckByteTransitionWithCapture()(1, 2, 13, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 8: 27 -[241-243]-> 25 | Capture Group: (0, 0)
        isValidTransition[8][i] <== CheckByteRangeTransitionWithCapture()(27, 25, 241, 243, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 9: 30 -[97-122]-> 19 | Capture Group: (0, 0)
        isValidTransition[9][i] <== CheckByteRangeTransitionWithCapture()(30, 19, 97, 122, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 10: 33 -[43]-> 34 | Capture Group: (1, 1)
        isValidTransition[10][i] <== CheckByteTransitionWithCapture()(33, 34, 43, 1, 1, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 11: 33 -[47-57]-> 34 | Capture Group: (1, 1)
        isValidTransition[11][i] <== CheckByteRangeTransitionWithCapture()(33, 34, 47, 57, 1, 1, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 12: 33 -[61]-> 34 | Capture Group: (1, 1)
        isValidTransition[12][i] <== CheckByteTransitionWithCapture()(33, 34, 61, 1, 1, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 13: 33 -[65-90]-> 34 | Capture Group: (1, 1)
        isValidTransition[13][i] <== CheckByteRangeTransitionWithCapture()(33, 34, 65, 90, 1, 1, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 14: 33 -[97-122]-> 34 | Capture Group: (1, 1)
        isValidTransition[14][i] <== CheckByteRangeTransitionWithCapture()(33, 34, 97, 122, 1, 1, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 15: 23 -[128-159]-> 20 | Capture Group: (0, 0)
        isValidTransition[15][i] <== CheckByteRangeTransitionWithCapture()(23, 20, 128, 159, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 16: 27 -[225-236]-> 22 | Capture Group: (0, 0)
        isValidTransition[16][i] <== CheckByteRangeTransitionWithCapture()(27, 22, 225, 236, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 17: 27 -[238-239]-> 22 | Capture Group: (0, 0)
        isValidTransition[17][i] <== CheckByteRangeTransitionWithCapture()(27, 22, 238, 239, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 18: 27 -[240]-> 24 | Capture Group: (0, 0)
        isValidTransition[18][i] <== CheckByteTransitionWithCapture()(27, 24, 240, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 19: 17 -[58]-> 18 | Capture Group: (0, 0)
        isValidTransition[19][i] <== CheckByteTransitionWithCapture()(17, 18, 58, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 20: 3 -[100]-> 4 | Capture Group: (0, 0)
        isValidTransition[20][i] <== CheckByteTransitionWithCapture()(3, 4, 100, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 21: 34 -[43]-> 34 | Capture Group: (0, 0)
        isValidTransition[21][i] <== CheckByteTransitionWithCapture()(34, 34, 43, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 22: 34 -[47-57]-> 34 | Capture Group: (0, 0)
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture()(34, 34, 47, 57, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 23: 34 -[61]-> 34 | Capture Group: (0, 0)
        isValidTransition[23][i] <== CheckByteTransitionWithCapture()(34, 34, 61, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 24: 34 -[65-90]-> 34 | Capture Group: (0, 0)
        isValidTransition[24][i] <== CheckByteRangeTransitionWithCapture()(34, 34, 65, 90, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 25: 34 -[97-122]-> 34 | Capture Group: (0, 0)
        isValidTransition[25][i] <== CheckByteRangeTransitionWithCapture()(34, 34, 97, 122, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 26: 4 -[107]-> 5 | Capture Group: (0, 0)
        isValidTransition[26][i] <== CheckByteTransitionWithCapture()(4, 5, 107, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 27: 28 -[240]-> 24 | Capture Group: (0, 0)
        isValidTransition[27][i] <== CheckByteTransitionWithCapture()(28, 24, 240, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 28: 32 -[61]-> 33 | Capture Group: (0, 0)
        isValidTransition[28][i] <== CheckByteTransitionWithCapture()(32, 33, 61, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 29: 13 -[116]-> 14 | Capture Group: (0, 0)
        isValidTransition[29][i] <== CheckByteTransitionWithCapture()(13, 14, 116, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 30: 34 -[59]-> 35 | Capture Group: (1, 0)
        isValidTransition[30][i] <== CheckByteTransitionWithCapture()(34, 35, 59, 1, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 31: 28 -[225-236]-> 22 | Capture Group: (0, 0)
        isValidTransition[31][i] <== CheckByteRangeTransitionWithCapture()(28, 22, 225, 236, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 32: 28 -[238-239]-> 22 | Capture Group: (0, 0)
        isValidTransition[32][i] <== CheckByteRangeTransitionWithCapture()(28, 22, 238, 239, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 33: 30 -[98]-> 31 | Capture Group: (0, 0)
        isValidTransition[33][i] <== CheckByteTransitionWithCapture()(30, 31, 98, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 34: 28 -[0-58]-> 28 | Capture Group: (0, 0)
        isValidTransition[34][i] <== CheckByteRangeTransitionWithCapture()(28, 28, 0, 58, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 35: 28 -[60-127]-> 28 | Capture Group: (0, 0)
        isValidTransition[35][i] <== CheckByteRangeTransitionWithCapture()(28, 28, 60, 127, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 36: 0 -[13]-> 2 | Capture Group: (0, 0)
        isValidTransition[36][i] <== CheckByteTransitionWithCapture()(0, 2, 13, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 37: 27 -[224]-> 21 | Capture Group: (0, 0)
        isValidTransition[37][i] <== CheckByteTransitionWithCapture()(27, 21, 224, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 38: 9 -[105]-> 10 | Capture Group: (0, 0)
        isValidTransition[38][i] <== CheckByteTransitionWithCapture()(9, 10, 105, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 39: 7 -[45]-> 8 | Capture Group: (0, 0)
        isValidTransition[39][i] <== CheckByteTransitionWithCapture()(7, 8, 45, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 40: 27 -[237]-> 23 | Capture Group: (0, 0)
        isValidTransition[40][i] <== CheckByteTransitionWithCapture()(27, 23, 237, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 41: 27 -[244]-> 26 | Capture Group: (0, 0)
        isValidTransition[41][i] <== CheckByteTransitionWithCapture()(27, 26, 244, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 42: 12 -[97]-> 13 | Capture Group: (0, 0)
        isValidTransition[42][i] <== CheckByteTransitionWithCapture()(12, 13, 97, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 43: 19 -[97-122]-> 19 | Capture Group: (0, 0)
        isValidTransition[43][i] <== CheckByteRangeTransitionWithCapture()(19, 19, 97, 122, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 44: 22 -[128-191]-> 20 | Capture Group: (0, 0)
        isValidTransition[44][i] <== CheckByteRangeTransitionWithCapture()(22, 20, 128, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 45: 28 -[244]-> 26 | Capture Group: (0, 0)
        isValidTransition[45][i] <== CheckByteTransitionWithCapture()(28, 26, 244, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 46: 5 -[105]-> 6 | Capture Group: (0, 0)
        isValidTransition[46][i] <== CheckByteTransitionWithCapture()(5, 6, 105, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 47: 31 -[104]-> 32 | Capture Group: (0, 0)
        isValidTransition[47][i] <== CheckByteTransitionWithCapture()(31, 32, 104, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 48: 0 -[100]-> 4 | Capture Group: (0, 0)
        isValidTransition[48][i] <== CheckByteTransitionWithCapture()(0, 4, 100, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 49: 19 -[61]-> 27 | Capture Group: (0, 0)
        isValidTransition[49][i] <== CheckByteTransitionWithCapture()(19, 27, 61, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 50: 20 -[128-191]-> 28 | Capture Group: (0, 0)
        isValidTransition[50][i] <== CheckByteRangeTransitionWithCapture()(20, 28, 128, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 51: 29 -[32]-> 30 | Capture Group: (0, 0)
        isValidTransition[51][i] <== CheckByteTransitionWithCapture()(29, 30, 32, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 52: 14 -[117]-> 15 | Capture Group: (0, 0)
        isValidTransition[52][i] <== CheckByteTransitionWithCapture()(14, 15, 117, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 53: 10 -[103]-> 11 | Capture Group: (0, 0)
        isValidTransition[53][i] <== CheckByteTransitionWithCapture()(10, 11, 103, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 54: 27 -[0-58]-> 28 | Capture Group: (0, 0)
        isValidTransition[54][i] <== CheckByteRangeTransitionWithCapture()(27, 28, 0, 58, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 55: 27 -[60-127]-> 28 | Capture Group: (0, 0)
        isValidTransition[55][i] <== CheckByteRangeTransitionWithCapture()(27, 28, 60, 127, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 56: 2 -[10]-> 3 | Capture Group: (0, 0)
        isValidTransition[56][i] <== CheckByteTransitionWithCapture()(2, 3, 10, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 57: 6 -[109]-> 7 | Capture Group: (0, 0)
        isValidTransition[57][i] <== CheckByteTransitionWithCapture()(6, 7, 109, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 58: 8 -[115]-> 9 | Capture Group: (0, 0)
        isValidTransition[58][i] <== CheckByteTransitionWithCapture()(8, 9, 115, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 59: 11 -[110]-> 12 | Capture Group: (0, 0)
        isValidTransition[59][i] <== CheckByteTransitionWithCapture()(11, 12, 110, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 60: 16 -[101]-> 17 | Capture Group: (0, 0)
        isValidTransition[60][i] <== CheckByteTransitionWithCapture()(16, 17, 101, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 61: 24 -[144-191]-> 22 | Capture Group: (0, 0)
        isValidTransition[61][i] <== CheckByteRangeTransitionWithCapture()(24, 22, 144, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 62: 26 -[128-143]-> 22 | Capture Group: (0, 0)
        isValidTransition[62][i] <== CheckByteRangeTransitionWithCapture()(26, 22, 128, 143, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 63: 15 -[114]-> 16 | Capture Group: (0, 0)
        isValidTransition[63][i] <== CheckByteTransitionWithCapture()(15, 16, 114, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 64: 27 -[194-223]-> 20 | Capture Group: (0, 0)
        isValidTransition[64][i] <== CheckByteRangeTransitionWithCapture()(27, 20, 194, 223, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 65: 28 -[194-223]-> 20 | Capture Group: (0, 0)
        isValidTransition[65][i] <== CheckByteRangeTransitionWithCapture()(28, 20, 194, 223, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);

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
    signal output capture1[128] <== CaptureSubstring(maxMatchBytes, 128, 1)(captureGroupStartIndices[0], haystack, captureGroupIds, captureGroupStarts);
}
