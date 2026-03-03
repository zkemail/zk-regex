pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: >([^<>]+)<.*
template ReversedBracketRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input captureGroup1Id[maxMatchBytes];
    signal input captureGroup1Start[maxMatchBytes];
    signal output isValid;

    var numStartStates = 2;
    var numAcceptStates = 1;
    var numTransitions = 49;
    var startStates[numStartStates] = [0, 1];
    var acceptStates[numAcceptStates] = [11];

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

        // Transition 0: 0 -[62]-> 2 | Capture Group: []
        isValidTransition[0][i] <== CheckByteTransitionWithCapture(1)(0, 2, 62, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 1: 1 -[62]-> 2 | Capture Group: []
        isValidTransition[1][i] <== CheckByteTransitionWithCapture(1)(1, 2, 62, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 2: 2 -[194-223]-> 3 | Capture Group:[ (1, 1)]
        isValidTransition[2][i] <== CheckByteRangeTransitionWithCapture(1)(2, 3, 194, 223, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 3: 2 -[224]-> 4 | Capture Group:[ (1, 1)]
        isValidTransition[3][i] <== CheckByteTransitionWithCapture(1)(2, 4, 224, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 4: 2 -[225-236]-> 5 | Capture Group:[ (1, 1)]
        isValidTransition[4][i] <== CheckByteRangeTransitionWithCapture(1)(2, 5, 225, 236, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 5: 2 -[238-239]-> 5 | Capture Group:[ (1, 1)]
        isValidTransition[5][i] <== CheckByteRangeTransitionWithCapture(1)(2, 5, 238, 239, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 6: 2 -[237]-> 6 | Capture Group:[ (1, 1)]
        isValidTransition[6][i] <== CheckByteTransitionWithCapture(1)(2, 6, 237, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 7: 2 -[240]-> 7 | Capture Group:[ (1, 1)]
        isValidTransition[7][i] <== CheckByteTransitionWithCapture(1)(2, 7, 240, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 8: 2 -[241-243]-> 8 | Capture Group:[ (1, 1)]
        isValidTransition[8][i] <== CheckByteRangeTransitionWithCapture(1)(2, 8, 241, 243, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 9: 2 -[244]-> 9 | Capture Group:[ (1, 1)]
        isValidTransition[9][i] <== CheckByteTransitionWithCapture(1)(2, 9, 244, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 10: 2 -[0-59]-> 10 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[10][i] <== CheckByteRangeTransitionWithCapture(1)(2, 10, 0, 59, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 11: 2 -[61]-> 10 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[11][i] <== CheckByteTransitionWithCapture(1)(2, 10, 61, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 12: 2 -[63-127]-> 10 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[12][i] <== CheckByteRangeTransitionWithCapture(1)(2, 10, 63, 127, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 13: 3 -[128-191]-> 10 | Capture Group:[ (1, 0)]
        isValidTransition[13][i] <== CheckByteRangeTransitionWithCapture(1)(3, 10, 128, 191, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 14: 4 -[160-191]-> 3 | Capture Group: []
        isValidTransition[14][i] <== CheckByteRangeTransitionWithCapture(1)(4, 3, 160, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 15: 5 -[128-191]-> 3 | Capture Group: []
        isValidTransition[15][i] <== CheckByteRangeTransitionWithCapture(1)(5, 3, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 16: 6 -[128-159]-> 3 | Capture Group: []
        isValidTransition[16][i] <== CheckByteRangeTransitionWithCapture(1)(6, 3, 128, 159, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 17: 7 -[144-191]-> 5 | Capture Group: []
        isValidTransition[17][i] <== CheckByteRangeTransitionWithCapture(1)(7, 5, 144, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 18: 8 -[128-191]-> 5 | Capture Group: []
        isValidTransition[18][i] <== CheckByteRangeTransitionWithCapture(1)(8, 5, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 19: 9 -[128-143]-> 5 | Capture Group: []
        isValidTransition[19][i] <== CheckByteRangeTransitionWithCapture(1)(9, 5, 128, 143, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 20: 10 -[194-223]-> 3 | Capture Group: []
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture(1)(10, 3, 194, 223, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 21: 10 -[224]-> 4 | Capture Group: []
        isValidTransition[21][i] <== CheckByteTransitionWithCapture(1)(10, 4, 224, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 22: 10 -[225-236]-> 5 | Capture Group: []
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture(1)(10, 5, 225, 236, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 23: 10 -[238-239]-> 5 | Capture Group: []
        isValidTransition[23][i] <== CheckByteRangeTransitionWithCapture(1)(10, 5, 238, 239, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 24: 10 -[237]-> 6 | Capture Group: []
        isValidTransition[24][i] <== CheckByteTransitionWithCapture(1)(10, 6, 237, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 25: 10 -[240]-> 7 | Capture Group: []
        isValidTransition[25][i] <== CheckByteTransitionWithCapture(1)(10, 7, 240, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 26: 10 -[241-243]-> 8 | Capture Group: []
        isValidTransition[26][i] <== CheckByteRangeTransitionWithCapture(1)(10, 8, 241, 243, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 27: 10 -[244]-> 9 | Capture Group: []
        isValidTransition[27][i] <== CheckByteTransitionWithCapture(1)(10, 9, 244, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 28: 10 -[0-59]-> 10 | Capture Group:[ (1, 0)]
        isValidTransition[28][i] <== CheckByteRangeTransitionWithCapture(1)(10, 10, 0, 59, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 29: 10 -[61]-> 10 | Capture Group:[ (1, 0)]
        isValidTransition[29][i] <== CheckByteTransitionWithCapture(1)(10, 10, 61, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 30: 10 -[63-127]-> 10 | Capture Group:[ (1, 0)]
        isValidTransition[30][i] <== CheckByteRangeTransitionWithCapture(1)(10, 10, 63, 127, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 31: 10 -[60]-> 11 | Capture Group: []
        isValidTransition[31][i] <== CheckByteTransitionWithCapture(1)(10, 11, 60, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 32: 11 -[0-9]-> 11 | Capture Group: []
        isValidTransition[32][i] <== CheckByteRangeTransitionWithCapture(1)(11, 11, 0, 9, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 33: 11 -[11-127]-> 11 | Capture Group: []
        isValidTransition[33][i] <== CheckByteRangeTransitionWithCapture(1)(11, 11, 11, 127, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 34: 11 -[194-223]-> 12 | Capture Group: []
        isValidTransition[34][i] <== CheckByteRangeTransitionWithCapture(1)(11, 12, 194, 223, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 35: 11 -[224]-> 13 | Capture Group: []
        isValidTransition[35][i] <== CheckByteTransitionWithCapture(1)(11, 13, 224, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 36: 11 -[225-236]-> 14 | Capture Group: []
        isValidTransition[36][i] <== CheckByteRangeTransitionWithCapture(1)(11, 14, 225, 236, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 37: 11 -[238-239]-> 14 | Capture Group: []
        isValidTransition[37][i] <== CheckByteRangeTransitionWithCapture(1)(11, 14, 238, 239, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 38: 11 -[237]-> 15 | Capture Group: []
        isValidTransition[38][i] <== CheckByteTransitionWithCapture(1)(11, 15, 237, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 39: 11 -[240]-> 16 | Capture Group: []
        isValidTransition[39][i] <== CheckByteTransitionWithCapture(1)(11, 16, 240, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 40: 11 -[241-243]-> 17 | Capture Group: []
        isValidTransition[40][i] <== CheckByteRangeTransitionWithCapture(1)(11, 17, 241, 243, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 41: 11 -[244]-> 18 | Capture Group: []
        isValidTransition[41][i] <== CheckByteTransitionWithCapture(1)(11, 18, 244, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 42: 12 -[128-191]-> 11 | Capture Group: []
        isValidTransition[42][i] <== CheckByteRangeTransitionWithCapture(1)(12, 11, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 43: 13 -[160-191]-> 12 | Capture Group: []
        isValidTransition[43][i] <== CheckByteRangeTransitionWithCapture(1)(13, 12, 160, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 44: 14 -[128-191]-> 12 | Capture Group: []
        isValidTransition[44][i] <== CheckByteRangeTransitionWithCapture(1)(14, 12, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 45: 15 -[128-159]-> 12 | Capture Group: []
        isValidTransition[45][i] <== CheckByteRangeTransitionWithCapture(1)(15, 12, 128, 159, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 46: 16 -[144-191]-> 14 | Capture Group: []
        isValidTransition[46][i] <== CheckByteRangeTransitionWithCapture(1)(16, 14, 144, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 47: 17 -[128-191]-> 14 | Capture Group: []
        isValidTransition[47][i] <== CheckByteRangeTransitionWithCapture(1)(17, 14, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 48: 18 -[128-143]-> 14 | Capture Group: []
        isValidTransition[48][i] <== CheckByteRangeTransitionWithCapture(1)(18, 14, 128, 143, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);

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
    signal output capture1[64] <== CaptureSubstring(maxMatchBytes, 64, 1)(captureGroupStartIndices[0], haystack, captureGroup1Id, captureGroup1Start);
}
