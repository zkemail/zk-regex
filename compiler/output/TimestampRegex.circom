pragma circom 2.1.5;

include "circomlib/comparators.circom";
include "circomlib/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (?:\r\n|^)dkim-signature:([a-z]+=[^;]+; )+t=([0-9]+);
template TimestampRegexRegex(maxBytes) {
    signal input currStates[maxBytes];
    signal input haystack[maxBytes];
    signal input nextStates[maxBytes];
    signal input traversalPathLength;

    var numStartStates = 2;
    var numAcceptStates = 1;
    var numTransitions = 59;
    var startStates[numStartStates] = [0, 1];
    var acceptStates[numAcceptStates] = [34];

    signal isCurrentState[numTransitions][maxBytes];
    signal isNextState[numTransitions][maxBytes];
    signal isValidTransition[numTransitions][maxBytes];
    signal reachedLastTransition[maxBytes];
    signal isValidRegex[maxBytes];
    signal isValidRegexTemp[maxBytes];
    signal isWithinPathLength[maxBytes];
    signal isTransitionLinked[maxBytes];

    component isValidStartState;

    signal reachedAcceptState[maxBytes];

    component isValidTraversal[maxBytes];

    // Check if the first state in the haystack is a valid start state
    isValidStartState = MultiOR(numStartStates);
    for (var i = 0; i < numStartStates; i++) {
        isValidStartState.in[i] <== IsEqual()([startStates[i], currStates[0]]);
    }
    isValidStartState.out === 1;

    for (var i = 0; i < maxBytes; i++) {
        isWithinPathLength[i] <== LessThan(log2Ceil(maxBytes))([i, traversalPathLength]);

        // Check if the traversal is a valid path
        if (i != maxBytes - 1) {
            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);
            isTransitionLinked[i] === isWithinPathLength[i];
        }

        // Transition 0: 14 -[117]-> 15
        isValidTransition[0][i] <== CheckByteTransition()(14, 15, 117, currStates[i], nextStates[i], haystack[i]);
        // Transition 1: 19 -[97-122]-> 19
        isValidTransition[1][i] <== CheckByteRangeTransition()(19, 19, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 2: 19 -[61]-> 27
        isValidTransition[2][i] <== CheckByteTransition()(19, 27, 61, currStates[i], nextStates[i], haystack[i]);
        // Transition 3: 24 -[144-191]-> 22
        isValidTransition[3][i] <== CheckByteRangeTransition()(24, 22, 144, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 4: 20 -[128-191]-> 28
        isValidTransition[4][i] <== CheckByteRangeTransition()(20, 28, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 5: 0 -[13]-> 2
        isValidTransition[5][i] <== CheckByteTransition()(0, 2, 13, currStates[i], nextStates[i], haystack[i]);
        // Transition 6: 22 -[128-191]-> 20
        isValidTransition[6][i] <== CheckByteRangeTransition()(22, 20, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 7: 27 -[194-223]-> 20
        isValidTransition[7][i] <== CheckByteRangeTransition()(27, 20, 194, 223, currStates[i], nextStates[i], haystack[i]);
        // Transition 8: 27 -[240]-> 24
        isValidTransition[8][i] <== CheckByteTransition()(27, 24, 240, currStates[i], nextStates[i], haystack[i]);
        // Transition 9: 27 -[244]-> 26
        isValidTransition[9][i] <== CheckByteTransition()(27, 26, 244, currStates[i], nextStates[i], haystack[i]);
        // Transition 10: 11 -[110]-> 12
        isValidTransition[10][i] <== CheckByteTransition()(11, 12, 110, currStates[i], nextStates[i], haystack[i]);
        // Transition 11: 25 -[128-191]-> 22
        isValidTransition[11][i] <== CheckByteRangeTransition()(25, 22, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 12: 12 -[97]-> 13
        isValidTransition[12][i] <== CheckByteTransition()(12, 13, 97, currStates[i], nextStates[i], haystack[i]);
        // Transition 13: 7 -[45]-> 8
        isValidTransition[13][i] <== CheckByteTransition()(7, 8, 45, currStates[i], nextStates[i], haystack[i]);
        // Transition 14: 17 -[58]-> 18
        isValidTransition[14][i] <== CheckByteTransition()(17, 18, 58, currStates[i], nextStates[i], haystack[i]);
        // Transition 15: 27 -[225-236]-> 22
        isValidTransition[15][i] <== CheckByteRangeTransition()(27, 22, 225, 236, currStates[i], nextStates[i], haystack[i]);
        // Transition 16: 27 -[238-239]-> 22
        isValidTransition[16][i] <== CheckByteRangeTransition()(27, 22, 238, 239, currStates[i], nextStates[i], haystack[i]);
        // Transition 17: 27 -[224]-> 21
        isValidTransition[17][i] <== CheckByteTransition()(27, 21, 224, currStates[i], nextStates[i], haystack[i]);
        // Transition 18: 27 -[237]-> 23
        isValidTransition[18][i] <== CheckByteTransition()(27, 23, 237, currStates[i], nextStates[i], haystack[i]);
        // Transition 19: 28 -[244]-> 26
        isValidTransition[19][i] <== CheckByteTransition()(28, 26, 244, currStates[i], nextStates[i], haystack[i]);
        // Transition 20: 30 -[116]-> 31
        isValidTransition[20][i] <== CheckByteTransition()(30, 31, 116, currStates[i], nextStates[i], haystack[i]);
        // Transition 21: 28 -[225-236]-> 22
        isValidTransition[21][i] <== CheckByteRangeTransition()(28, 22, 225, 236, currStates[i], nextStates[i], haystack[i]);
        // Transition 22: 28 -[238-239]-> 22
        isValidTransition[22][i] <== CheckByteRangeTransition()(28, 22, 238, 239, currStates[i], nextStates[i], haystack[i]);
        // Transition 23: 28 -[194-223]-> 20
        isValidTransition[23][i] <== CheckByteRangeTransition()(28, 20, 194, 223, currStates[i], nextStates[i], haystack[i]);
        // Transition 24: 4 -[107]-> 5
        isValidTransition[24][i] <== CheckByteTransition()(4, 5, 107, currStates[i], nextStates[i], haystack[i]);
        // Transition 25: 3 -[100]-> 4
        isValidTransition[25][i] <== CheckByteTransition()(3, 4, 100, currStates[i], nextStates[i], haystack[i]);
        // Transition 26: 28 -[224]-> 21
        isValidTransition[26][i] <== CheckByteTransition()(28, 21, 224, currStates[i], nextStates[i], haystack[i]);
        // Transition 27: 28 -[0-58]-> 28
        isValidTransition[27][i] <== CheckByteRangeTransition()(28, 28, 0, 58, currStates[i], nextStates[i], haystack[i]);
        // Transition 28: 28 -[60-127]-> 28
        isValidTransition[28][i] <== CheckByteRangeTransition()(28, 28, 60, 127, currStates[i], nextStates[i], haystack[i]);
        // Transition 29: 5 -[105]-> 6
        isValidTransition[29][i] <== CheckByteTransition()(5, 6, 105, currStates[i], nextStates[i], haystack[i]);
        // Transition 30: 0 -[100]-> 4
        isValidTransition[30][i] <== CheckByteTransition()(0, 4, 100, currStates[i], nextStates[i], haystack[i]);
        // Transition 31: 15 -[114]-> 16
        isValidTransition[31][i] <== CheckByteTransition()(15, 16, 114, currStates[i], nextStates[i], haystack[i]);
        // Transition 32: 6 -[109]-> 7
        isValidTransition[32][i] <== CheckByteTransition()(6, 7, 109, currStates[i], nextStates[i], haystack[i]);
        // Transition 33: 27 -[241-243]-> 25
        isValidTransition[33][i] <== CheckByteRangeTransition()(27, 25, 241, 243, currStates[i], nextStates[i], haystack[i]);
        // Transition 34: 28 -[240]-> 24
        isValidTransition[34][i] <== CheckByteTransition()(28, 24, 240, currStates[i], nextStates[i], haystack[i]);
        // Transition 35: 1 -[100]-> 4
        isValidTransition[35][i] <== CheckByteTransition()(1, 4, 100, currStates[i], nextStates[i], haystack[i]);
        // Transition 36: 8 -[115]-> 9
        isValidTransition[36][i] <== CheckByteTransition()(8, 9, 115, currStates[i], nextStates[i], haystack[i]);
        // Transition 37: 18 -[97-122]-> 19
        isValidTransition[37][i] <== CheckByteRangeTransition()(18, 19, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 38: 13 -[116]-> 14
        isValidTransition[38][i] <== CheckByteTransition()(13, 14, 116, currStates[i], nextStates[i], haystack[i]);
        // Transition 39: 26 -[128-143]-> 22
        isValidTransition[39][i] <== CheckByteRangeTransition()(26, 22, 128, 143, currStates[i], nextStates[i], haystack[i]);
        // Transition 40: 28 -[59]-> 29
        isValidTransition[40][i] <== CheckByteTransition()(28, 29, 59, currStates[i], nextStates[i], haystack[i]);
        // Transition 41: 28 -[237]-> 23
        isValidTransition[41][i] <== CheckByteTransition()(28, 23, 237, currStates[i], nextStates[i], haystack[i]);
        // Transition 42: 1 -[13]-> 2
        isValidTransition[42][i] <== CheckByteTransition()(1, 2, 13, currStates[i], nextStates[i], haystack[i]);
        // Transition 43: 28 -[241-243]-> 25
        isValidTransition[43][i] <== CheckByteRangeTransition()(28, 25, 241, 243, currStates[i], nextStates[i], haystack[i]);
        // Transition 44: 0 -[0-255]-> 0
        isValidTransition[44][i] <== CheckByteRangeTransition()(0, 0, 0, 255, currStates[i], nextStates[i], haystack[i]);
        // Transition 45: 21 -[160-191]-> 20
        isValidTransition[45][i] <== CheckByteRangeTransition()(21, 20, 160, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 46: 27 -[0-58]-> 28
        isValidTransition[46][i] <== CheckByteRangeTransition()(27, 28, 0, 58, currStates[i], nextStates[i], haystack[i]);
        // Transition 47: 27 -[60-127]-> 28
        isValidTransition[47][i] <== CheckByteRangeTransition()(27, 28, 60, 127, currStates[i], nextStates[i], haystack[i]);
        // Transition 48: 31 -[61]-> 32
        isValidTransition[48][i] <== CheckByteTransition()(31, 32, 61, currStates[i], nextStates[i], haystack[i]);
        // Transition 49: 23 -[128-159]-> 20
        isValidTransition[49][i] <== CheckByteRangeTransition()(23, 20, 128, 159, currStates[i], nextStates[i], haystack[i]);
        // Transition 50: 33 -[48-57]-> 33
        isValidTransition[50][i] <== CheckByteRangeTransition()(33, 33, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 51: 9 -[105]-> 10
        isValidTransition[51][i] <== CheckByteTransition()(9, 10, 105, currStates[i], nextStates[i], haystack[i]);
        // Transition 52: 32 -[48-57]-> 33
        isValidTransition[52][i] <== CheckByteRangeTransition()(32, 33, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 53: 29 -[32]-> 30
        isValidTransition[53][i] <== CheckByteTransition()(29, 30, 32, currStates[i], nextStates[i], haystack[i]);
        // Transition 54: 33 -[59]-> 34
        isValidTransition[54][i] <== CheckByteTransition()(33, 34, 59, currStates[i], nextStates[i], haystack[i]);
        // Transition 55: 2 -[10]-> 3
        isValidTransition[55][i] <== CheckByteTransition()(2, 3, 10, currStates[i], nextStates[i], haystack[i]);
        // Transition 56: 16 -[101]-> 17
        isValidTransition[56][i] <== CheckByteTransition()(16, 17, 101, currStates[i], nextStates[i], haystack[i]);
        // Transition 57: 30 -[97-122]-> 19
        isValidTransition[57][i] <== CheckByteRangeTransition()(30, 19, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 58: 10 -[103]-> 11
        isValidTransition[58][i] <== CheckByteTransition()(10, 11, 103, currStates[i], nextStates[i], haystack[i]);

        // Combine all valid transitions for this byte
        isValidTraversal[i] = MultiOR(numTransitions);
        for (var j = 0; j < numTransitions; j++) {
            isValidTraversal[i].in[j] <== isValidTransition[j][i];
        }
        isValidTraversal[i].out === isWithinPathLength[i];

        // Check if any accept state has been reached at the last transition
        reachedLastTransition[i] <== IsEqual()([i, traversalPathLength-1]);
        reachedAcceptState[i] <== IsEqual()([nextStates[i], acceptStates[0]]);
        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i]);
        if (i == 0) {
            isValidRegex[i] <== isValidRegexTemp[i];
        } else {
            isValidRegex[i] <== isValidRegexTemp[i] + isValidRegex[i-1];
        }
    }
    isValidRegex[maxBytes-1] === 1;

}
