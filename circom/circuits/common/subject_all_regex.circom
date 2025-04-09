pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";
include "@zk-email/circuits/utils/array.circom";

// regex: (?:\r\n|^)subject:[^\r\n]+\r\n
template SubjectAllRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input traversalPathLength;

    signal output isValid;

    var numStartStates = 7;
    var numAcceptStates = 2;
    var numTransitions = 51;
    var startStates[numStartStates] = [0, 1, 2, 3, 5, 6, 7];
    var acceptStates[numAcceptStates] = [26, 27];

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

    component reachedAcceptState[maxMatchBytes];

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
        isWithinPathLength[i] <== LessThan(log2Ceil(maxMatchBytes))([i, traversalPathLength]);

        // Check if the traversal is a valid path
        if (i < maxMatchBytes-2) {
            isWithinPathLengthMinusOne[i] <== LessThan(log2Ceil(maxMatchBytes))([i, traversalPathLength-1]);
            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);
            isTransitionLinked[i] === isWithinPathLengthMinusOne[i];
        }

        // Transition 0: 0 -[115]-> 8
        isValidTransition[0][i] <== CheckByteTransition()(0, 8, 115, currStates[i], nextStates[i], haystack[i]);
        // Transition 1: 22 -[240]-> 19
        isValidTransition[1][i] <== CheckByteTransition()(22, 19, 240, currStates[i], nextStates[i], haystack[i]);
        // Transition 2: 0 -[0-255]-> 0
        isValidTransition[2][i] <== CheckByteRangeTransition()(0, 0, 0, 255, currStates[i], nextStates[i], haystack[i]);
        // Transition 3: 1 -[0-255]-> 0
        isValidTransition[3][i] <== CheckByteRangeTransition()(1, 0, 0, 255, currStates[i], nextStates[i], haystack[i]);
        // Transition 4: 23 -[224]-> 16
        isValidTransition[4][i] <== CheckByteTransition()(23, 16, 224, currStates[i], nextStates[i], haystack[i]);
        // Transition 5: 3 -[13]-> 4
        isValidTransition[5][i] <== CheckByteTransition()(3, 4, 13, currStates[i], nextStates[i], haystack[i]);
        // Transition 6: 6 -[13]-> 4
        isValidTransition[6][i] <== CheckByteTransition()(6, 4, 13, currStates[i], nextStates[i], haystack[i]);
        // Transition 7: 22 -[194-223]-> 15
        isValidTransition[7][i] <== CheckByteRangeTransition()(22, 15, 194, 223, currStates[i], nextStates[i], haystack[i]);
        // Transition 8: 16 -[160-191]-> 15
        isValidTransition[8][i] <== CheckByteRangeTransition()(16, 15, 160, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 9: 4 -[10]-> 7
        isValidTransition[9][i] <== CheckByteTransition()(4, 7, 10, currStates[i], nextStates[i], haystack[i]);
        // Transition 10: 11 -[101]-> 12
        isValidTransition[10][i] <== CheckByteTransition()(11, 12, 101, currStates[i], nextStates[i], haystack[i]);
        // Transition 11: 7 -[115]-> 8
        isValidTransition[11][i] <== CheckByteTransition()(7, 8, 115, currStates[i], nextStates[i], haystack[i]);
        // Transition 12: 8 -[117]-> 9
        isValidTransition[12][i] <== CheckByteTransition()(8, 9, 117, currStates[i], nextStates[i], haystack[i]);
        // Transition 13: 18 -[128-159]-> 15
        isValidTransition[13][i] <== CheckByteRangeTransition()(18, 15, 128, 159, currStates[i], nextStates[i], haystack[i]);
        // Transition 14: 19 -[144-191]-> 17
        isValidTransition[14][i] <== CheckByteRangeTransition()(19, 17, 144, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 15: 22 -[224]-> 16
        isValidTransition[15][i] <== CheckByteTransition()(22, 16, 224, currStates[i], nextStates[i], haystack[i]);
        // Transition 16: 2 -[115]-> 8
        isValidTransition[16][i] <== CheckByteTransition()(2, 8, 115, currStates[i], nextStates[i], haystack[i]);
        // Transition 17: 6 -[115]-> 8
        isValidTransition[17][i] <== CheckByteTransition()(6, 8, 115, currStates[i], nextStates[i], haystack[i]);
        // Transition 18: 0 -[13]-> 4
        isValidTransition[18][i] <== CheckByteTransition()(0, 4, 13, currStates[i], nextStates[i], haystack[i]);
        // Transition 19: 9 -[98]-> 10
        isValidTransition[19][i] <== CheckByteTransition()(9, 10, 98, currStates[i], nextStates[i], haystack[i]);
        // Transition 20: 22 -[225-236]-> 17
        isValidTransition[20][i] <== CheckByteRangeTransition()(22, 17, 225, 236, currStates[i], nextStates[i], haystack[i]);
        // Transition 21: 22 -[238-239]-> 17
        isValidTransition[21][i] <== CheckByteRangeTransition()(22, 17, 238, 239, currStates[i], nextStates[i], haystack[i]);
        // Transition 22: 15 -[128-191]-> 23
        isValidTransition[22][i] <== CheckByteRangeTransition()(15, 23, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 23: 10 -[106]-> 11
        isValidTransition[23][i] <== CheckByteTransition()(10, 11, 106, currStates[i], nextStates[i], haystack[i]);
        // Transition 24: 17 -[128-191]-> 15
        isValidTransition[24][i] <== CheckByteRangeTransition()(17, 15, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 25: 22 -[244]-> 21
        isValidTransition[25][i] <== CheckByteTransition()(22, 21, 244, currStates[i], nextStates[i], haystack[i]);
        // Transition 26: 23 -[0-9]-> 23
        isValidTransition[26][i] <== CheckByteRangeTransition()(23, 23, 0, 9, currStates[i], nextStates[i], haystack[i]);
        // Transition 27: 23 -[11-12]-> 23
        isValidTransition[27][i] <== CheckByteRangeTransition()(23, 23, 11, 12, currStates[i], nextStates[i], haystack[i]);
        // Transition 28: 23 -[14-127]-> 23
        isValidTransition[28][i] <== CheckByteRangeTransition()(23, 23, 14, 127, currStates[i], nextStates[i], haystack[i]);
        // Transition 29: 23 -[13]-> 25
        isValidTransition[29][i] <== CheckByteTransition()(23, 25, 13, currStates[i], nextStates[i], haystack[i]);
        // Transition 30: 5 -[115]-> 8
        isValidTransition[30][i] <== CheckByteTransition()(5, 8, 115, currStates[i], nextStates[i], haystack[i]);
        // Transition 31: 22 -[241-243]-> 20
        isValidTransition[31][i] <== CheckByteRangeTransition()(22, 20, 241, 243, currStates[i], nextStates[i], haystack[i]);
        // Transition 32: 22 -[0-9]-> 23
        isValidTransition[32][i] <== CheckByteRangeTransition()(22, 23, 0, 9, currStates[i], nextStates[i], haystack[i]);
        // Transition 33: 22 -[11-12]-> 23
        isValidTransition[33][i] <== CheckByteRangeTransition()(22, 23, 11, 12, currStates[i], nextStates[i], haystack[i]);
        // Transition 34: 22 -[14-127]-> 23
        isValidTransition[34][i] <== CheckByteRangeTransition()(22, 23, 14, 127, currStates[i], nextStates[i], haystack[i]);
        // Transition 35: 23 -[244]-> 21
        isValidTransition[35][i] <== CheckByteTransition()(23, 21, 244, currStates[i], nextStates[i], haystack[i]);
        // Transition 36: 24 -[13]-> 25
        isValidTransition[36][i] <== CheckByteTransition()(24, 25, 13, currStates[i], nextStates[i], haystack[i]);
        // Transition 37: 25 -[10]-> 26
        isValidTransition[37][i] <== CheckByteTransition()(25, 26, 10, currStates[i], nextStates[i], haystack[i]);
        // Transition 38: 22 -[237]-> 18
        isValidTransition[38][i] <== CheckByteTransition()(22, 18, 237, currStates[i], nextStates[i], haystack[i]);
        // Transition 39: 21 -[128-143]-> 17
        isValidTransition[39][i] <== CheckByteRangeTransition()(21, 17, 128, 143, currStates[i], nextStates[i], haystack[i]);
        // Transition 40: 23 -[225-236]-> 17
        isValidTransition[40][i] <== CheckByteRangeTransition()(23, 17, 225, 236, currStates[i], nextStates[i], haystack[i]);
        // Transition 41: 23 -[238-239]-> 17
        isValidTransition[41][i] <== CheckByteRangeTransition()(23, 17, 238, 239, currStates[i], nextStates[i], haystack[i]);
        // Transition 42: 23 -[237]-> 18
        isValidTransition[42][i] <== CheckByteTransition()(23, 18, 237, currStates[i], nextStates[i], haystack[i]);
        // Transition 43: 12 -[99]-> 13
        isValidTransition[43][i] <== CheckByteTransition()(12, 13, 99, currStates[i], nextStates[i], haystack[i]);
        // Transition 44: 13 -[116]-> 14
        isValidTransition[44][i] <== CheckByteTransition()(13, 14, 116, currStates[i], nextStates[i], haystack[i]);
        // Transition 45: 23 -[240]-> 19
        isValidTransition[45][i] <== CheckByteTransition()(23, 19, 240, currStates[i], nextStates[i], haystack[i]);
        // Transition 46: 23 -[241-243]-> 20
        isValidTransition[46][i] <== CheckByteRangeTransition()(23, 20, 241, 243, currStates[i], nextStates[i], haystack[i]);
        // Transition 47: 14 -[58]-> 22
        isValidTransition[47][i] <== CheckByteTransition()(14, 22, 58, currStates[i], nextStates[i], haystack[i]);
        // Transition 48: 20 -[128-191]-> 17
        isValidTransition[48][i] <== CheckByteRangeTransition()(20, 17, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 49: 2 -[13]-> 4
        isValidTransition[49][i] <== CheckByteTransition()(2, 4, 13, currStates[i], nextStates[i], haystack[i]);
        // Transition 50: 23 -[194-223]-> 15
        isValidTransition[50][i] <== CheckByteRangeTransition()(23, 15, 194, 223, currStates[i], nextStates[i], haystack[i]);

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
        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i].out);
        if (i == 0) {
            isValidRegex[i] <== isValidRegexTemp[i];
        } else {
            isValidRegex[i] <== isValidRegexTemp[i] + isValidRegex[i-1];
        }
    }

    isValid <== isValidRegex[maxMatchBytes-1];

}
