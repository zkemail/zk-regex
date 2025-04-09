pragma circom 2.1.5;

include "circomlib/comparators.circom";
include "circomlib/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (?:\r\n|^)dkim-signature:(?:[a-z]+=[^;]+; )+t=([0-9]+);
template TimestampRegex(maxHaystackBytes, maxMatchBytes) {
    signal input in[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input captureGroupIds[maxMatchBytes];
    signal input captureGroupStarts[maxMatchBytes];
    signal input traversalPathLength;

    var numStartStates = 7;
    var numAcceptStates = 2;
    var numTransitions = 70;
    var startStates[numStartStates] = [0, 1, 2, 3, 5, 6, 7];
    var acceptStates[numAcceptStates] = [44, 45];

    signal isCurrentState[numTransitions][maxMatchBytes];
    signal isNextState[numTransitions][maxMatchBytes];
    signal isValidTransition[numTransitions][maxMatchBytes];
    signal reachedLastTransition[maxMatchBytes];
    signal isValidRegex[maxMatchBytes];
    signal isValidRegexTemp[maxMatchBytes];
    signal isWithinPathLength[maxMatchBytes];
    signal isTransitionLinked[maxMatchBytes];

    component isValidStartState;

    component reachedAcceptState[maxMatchBytes];

    component isValidTraversal[maxMatchBytes];

    signal haystack[maxMatchBytes] <== SelectSubArray(maxHaystackBytes, maxMatchBytes)(in, matchStart, matchLength);

    // Check if the first state in the haystack is a valid start state
    isValidStartState = MultiOR(numStartStates);
    for (var i = 0; i < numStartStates; i++) {
        isValidStartState.in[i] <== IsEqual()([startStates[i], currStates[0]]);
    }
    isValidStartState.out === 1;

    for (var i = 0; i < maxMatchBytes; i++) {
        isWithinPathLength[i] <== LessThan(log2Ceil(maxMatchBytes))([i, traversalPathLength-1]);

        // Check if the traversal is a valid path
        if (i != maxMatchBytes-1) {
            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);
            log("i", i);
            log("nextStates[i]", nextStates[i]);
            log("currStates[i+1]", currStates[i+1]);
            log("isWithinPathLength[i]", isWithinPathLength[i]);
            isTransitionLinked[i] === isWithinPathLength[i];
        }

        // Transition 0: 17 -[116]-> 18 | Capture Group: (0, 0)
        isValidTransition[0][i] <== CheckByteTransitionWithCapture()(17, 18, 116, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 1: 12 -[115]-> 13 | Capture Group: (0, 0)
        isValidTransition[1][i] <== CheckByteTransitionWithCapture()(12, 13, 115, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 2: 32 -[241-243]-> 30 | Capture Group: (0, 0)
        isValidTransition[2][i] <== CheckByteRangeTransitionWithCapture()(32, 30, 241, 243, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 3: 42 -[59]-> 44 | Capture Group: (1, 0)
        isValidTransition[3][i] <== CheckByteTransitionWithCapture()(42, 44, 59, 1, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 4: 37 -[116]-> 38 | Capture Group: (0, 0)
        isValidTransition[4][i] <== CheckByteTransitionWithCapture()(37, 38, 116, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 5: 5 -[100]-> 8 | Capture Group: (0, 0)
        isValidTransition[5][i] <== CheckByteTransitionWithCapture()(5, 8, 100, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 6: 0 -[0-255]-> 0 | Capture Group: (0, 0)
        isValidTransition[6][i] <== CheckByteRangeTransitionWithCapture()(0, 0, 0, 255, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 7: 16 -[97]-> 17 | Capture Group: (0, 0)
        isValidTransition[7][i] <== CheckByteTransitionWithCapture()(16, 17, 97, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 8: 32 -[0-58]-> 33 | Capture Group: (0, 0)
        isValidTransition[8][i] <== CheckByteRangeTransitionWithCapture()(32, 33, 0, 58, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 9: 32 -[60-127]-> 33 | Capture Group: (0, 0)
        isValidTransition[9][i] <== CheckByteRangeTransitionWithCapture()(32, 33, 60, 127, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 10: 43 -[59]-> 44 | Capture Group: (0, 0)
        isValidTransition[10][i] <== CheckByteTransitionWithCapture()(43, 44, 59, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 11: 8 -[107]-> 9 | Capture Group: (0, 0)
        isValidTransition[11][i] <== CheckByteTransitionWithCapture()(8, 9, 107, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 12: 32 -[244]-> 31 | Capture Group: (0, 0)
        isValidTransition[12][i] <== CheckByteTransitionWithCapture()(32, 31, 244, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 13: 13 -[105]-> 14 | Capture Group: (0, 0)
        isValidTransition[13][i] <== CheckByteTransitionWithCapture()(13, 14, 105, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 14: 11 -[45]-> 12 | Capture Group: (0, 0)
        isValidTransition[14][i] <== CheckByteTransitionWithCapture()(11, 12, 45, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 15: 2 -[100]-> 8 | Capture Group: (0, 0)
        isValidTransition[15][i] <== CheckByteTransitionWithCapture()(2, 8, 100, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 16: 33 -[241-243]-> 30 | Capture Group: (0, 0)
        isValidTransition[16][i] <== CheckByteRangeTransitionWithCapture()(33, 30, 241, 243, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 17: 7 -[100]-> 8 | Capture Group: (0, 0)
        isValidTransition[17][i] <== CheckByteTransitionWithCapture()(7, 8, 100, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 18: 23 -[97-122]-> 23 | Capture Group: (0, 0)
        isValidTransition[18][i] <== CheckByteRangeTransitionWithCapture()(23, 23, 97, 122, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 19: 29 -[144-191]-> 27 | Capture Group: (0, 0)
        isValidTransition[19][i] <== CheckByteRangeTransitionWithCapture()(29, 27, 144, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 20: 32 -[194-223]-> 25 | Capture Group: (0, 0)
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture()(32, 25, 194, 223, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 21: 15 -[110]-> 16 | Capture Group: (0, 0)
        isValidTransition[21][i] <== CheckByteTransitionWithCapture()(15, 16, 110, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 22: 33 -[0-58]-> 33 | Capture Group: (0, 0)
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture()(33, 33, 0, 58, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 23: 33 -[60-127]-> 33 | Capture Group: (0, 0)
        isValidTransition[23][i] <== CheckByteRangeTransitionWithCapture()(33, 33, 60, 127, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 24: 33 -[225-236]-> 27 | Capture Group: (0, 0)
        isValidTransition[24][i] <== CheckByteRangeTransitionWithCapture()(33, 27, 225, 236, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 25: 33 -[238-239]-> 27 | Capture Group: (0, 0)
        isValidTransition[25][i] <== CheckByteRangeTransitionWithCapture()(33, 27, 238, 239, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 26: 3 -[13]-> 4 | Capture Group: (0, 0)
        isValidTransition[26][i] <== CheckByteTransitionWithCapture()(3, 4, 13, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 27: 41 -[48-57]-> 41 | Capture Group: (0, 0)
        isValidTransition[27][i] <== CheckByteRangeTransitionWithCapture()(41, 41, 48, 57, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 28: 33 -[237]-> 28 | Capture Group: (0, 0)
        isValidTransition[28][i] <== CheckByteTransitionWithCapture()(33, 28, 237, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 29: 34 -[59]-> 35 | Capture Group: (0, 0)
        isValidTransition[29][i] <== CheckByteTransitionWithCapture()(34, 35, 59, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 30: 33 -[194-223]-> 25 | Capture Group: (0, 0)
        isValidTransition[30][i] <== CheckByteRangeTransitionWithCapture()(33, 25, 194, 223, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 31: 20 -[101]-> 21 | Capture Group: (0, 0)
        isValidTransition[31][i] <== CheckByteTransitionWithCapture()(20, 21, 101, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 32: 36 -[116]-> 38 | Capture Group: (0, 0)
        isValidTransition[32][i] <== CheckByteTransitionWithCapture()(36, 38, 116, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 33: 4 -[10]-> 7 | Capture Group: (0, 0)
        isValidTransition[33][i] <== CheckByteTransitionWithCapture()(4, 7, 10, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 34: 6 -[13]-> 4 | Capture Group: (0, 0)
        isValidTransition[34][i] <== CheckByteTransitionWithCapture()(6, 4, 13, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 35: 2 -[13]-> 4 | Capture Group: (0, 0)
        isValidTransition[35][i] <== CheckByteTransitionWithCapture()(2, 4, 13, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 36: 0 -[13]-> 4 | Capture Group: (0, 0)
        isValidTransition[36][i] <== CheckByteTransitionWithCapture()(0, 4, 13, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 37: 10 -[109]-> 11 | Capture Group: (0, 0)
        isValidTransition[37][i] <== CheckByteTransitionWithCapture()(10, 11, 109, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 38: 1 -[0-255]-> 0 | Capture Group: (0, 0)
        isValidTransition[38][i] <== CheckByteRangeTransitionWithCapture()(1, 0, 0, 255, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 39: 22 -[97-122]-> 23 | Capture Group: (0, 0)
        isValidTransition[39][i] <== CheckByteRangeTransitionWithCapture()(22, 23, 97, 122, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 40: 27 -[128-191]-> 25 | Capture Group: (0, 0)
        isValidTransition[40][i] <== CheckByteRangeTransitionWithCapture()(27, 25, 128, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 41: 33 -[224]-> 26 | Capture Group: (0, 0)
        isValidTransition[41][i] <== CheckByteTransitionWithCapture()(33, 26, 224, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 42: 25 -[128-191]-> 33 | Capture Group: (0, 0)
        isValidTransition[42][i] <== CheckByteRangeTransitionWithCapture()(25, 33, 128, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 43: 24 -[61]-> 32 | Capture Group: (0, 0)
        isValidTransition[43][i] <== CheckByteTransitionWithCapture()(24, 32, 61, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 44: 32 -[240]-> 29 | Capture Group: (0, 0)
        isValidTransition[44][i] <== CheckByteTransitionWithCapture()(32, 29, 240, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 45: 14 -[103]-> 15 | Capture Group: (0, 0)
        isValidTransition[45][i] <== CheckByteTransitionWithCapture()(14, 15, 103, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 46: 31 -[128-143]-> 27 | Capture Group: (0, 0)
        isValidTransition[46][i] <== CheckByteRangeTransitionWithCapture()(31, 27, 128, 143, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 47: 9 -[105]-> 10 | Capture Group: (0, 0)
        isValidTransition[47][i] <== CheckByteTransitionWithCapture()(9, 10, 105, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 48: 6 -[100]-> 8 | Capture Group: (0, 0)
        isValidTransition[48][i] <== CheckByteTransitionWithCapture()(6, 8, 100, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 49: 21 -[58]-> 22 | Capture Group: (0, 0)
        isValidTransition[49][i] <== CheckByteTransitionWithCapture()(21, 22, 58, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 50: 32 -[237]-> 28 | Capture Group: (0, 0)
        isValidTransition[50][i] <== CheckByteTransitionWithCapture()(32, 28, 237, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 51: 32 -[224]-> 26 | Capture Group: (0, 0)
        isValidTransition[51][i] <== CheckByteTransitionWithCapture()(32, 26, 224, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 52: 28 -[128-159]-> 25 | Capture Group: (0, 0)
        isValidTransition[52][i] <== CheckByteRangeTransitionWithCapture()(28, 25, 128, 159, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 53: 35 -[32]-> 36 | Capture Group: (0, 0)
        isValidTransition[53][i] <== CheckByteTransitionWithCapture()(35, 36, 32, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 54: 18 -[117]-> 19 | Capture Group: (0, 0)
        isValidTransition[54][i] <== CheckByteTransitionWithCapture()(18, 19, 117, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 55: 19 -[114]-> 20 | Capture Group: (0, 0)
        isValidTransition[55][i] <== CheckByteTransitionWithCapture()(19, 20, 114, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 56: 26 -[160-191]-> 25 | Capture Group: (0, 0)
        isValidTransition[56][i] <== CheckByteRangeTransitionWithCapture()(26, 25, 160, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 57: 36 -[97-122]-> 23 | Capture Group: (0, 0)
        isValidTransition[57][i] <== CheckByteRangeTransitionWithCapture()(36, 23, 97, 122, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 58: 33 -[240]-> 29 | Capture Group: (0, 0)
        isValidTransition[58][i] <== CheckByteTransitionWithCapture()(33, 29, 240, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 59: 33 -[244]-> 31 | Capture Group: (0, 0)
        isValidTransition[59][i] <== CheckByteTransitionWithCapture()(33, 31, 244, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 60: 39 -[48-57]-> 41 | Capture Group: (1, 1)
        isValidTransition[60][i] <== CheckByteRangeTransitionWithCapture()(39, 41, 48, 57, 1, 1, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 61: 30 -[128-191]-> 27 | Capture Group: (0, 0)
        isValidTransition[61][i] <== CheckByteRangeTransitionWithCapture()(30, 27, 128, 191, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 62: 38 -[61]-> 39 | Capture Group: (0, 0)
        isValidTransition[62][i] <== CheckByteTransitionWithCapture()(38, 39, 61, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 63: 40 -[48-57]-> 41 | Capture Group: (0, 0)
        isValidTransition[63][i] <== CheckByteRangeTransitionWithCapture()(40, 41, 48, 57, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 64: 32 -[225-236]-> 27 | Capture Group: (0, 0)
        isValidTransition[64][i] <== CheckByteRangeTransitionWithCapture()(32, 27, 225, 236, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 65: 32 -[238-239]-> 27 | Capture Group: (0, 0)
        isValidTransition[65][i] <== CheckByteRangeTransitionWithCapture()(32, 27, 238, 239, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 66: 41 -[59]-> 44 | Capture Group: (1, 0)
        isValidTransition[66][i] <== CheckByteTransitionWithCapture()(41, 44, 59, 1, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 67: 23 -[61]-> 32 | Capture Group: (0, 0)
        isValidTransition[67][i] <== CheckByteTransitionWithCapture()(23, 32, 61, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 68: 0 -[100]-> 8 | Capture Group: (0, 0)
        isValidTransition[68][i] <== CheckByteTransitionWithCapture()(0, 8, 100, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 69: 33 -[59]-> 35 | Capture Group: (0, 0)
        isValidTransition[69][i] <== CheckByteTransitionWithCapture()(33, 35, 59, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);

        // Combine all valid transitions for this byte
        isValidTraversal[i] = MultiOR(numTransitions);
        for (var j = 0; j < numTransitions; j++) {
            isValidTraversal[i].in[j] <== isValidTransition[j][i];
        }
        isValidTraversal[i].out === isWithinPathLength[i];

        // Check if any accept state has been reached at the last transition
        reachedLastTransition[i] <== IsEqual()([i, traversalPathLength-1]);
        reachedAcceptState[i] = MultiOR(numAcceptStates);
        for (var j = 0; j < numAcceptStates; j++) {
            reachedAcceptState[i].in[j] <== IsEqual()([nextStates[i], acceptStates[j]]);
        }
        reachedAcceptState[i].out === 1;
        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i].out);
        if (i == 0) {
            isValidRegex[i] <== isValidRegexTemp[i];
        } else {
            isValidRegex[i] <== isValidRegexTemp[i] + isValidRegex[i-1];
        }
    }
    isValidRegex[maxMatchBytes-1] === 1;

    // Capture Group 1
    signal input capture1StartIndex;
    signal output capture1[10] <== CaptureSubstring(maxMatchBytes, 10, 1)(capture1StartIndex, haystack, captureGroupIds, captureGroupStarts);
}