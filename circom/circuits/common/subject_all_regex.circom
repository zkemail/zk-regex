pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (?:\r\n|^)subject:([^\r\n]+)\r\n
template SubjectAllRegex(maxHaystackBytes, maxMatchBytes) {
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
    var numTransitions = 43;
    var startStates[numStartStates] = [0, 1, 3];
    var acceptStates[numAcceptStates] = [21];

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
        // Transition 1: 0 -[115]-> 4 | Capture Group: []
        isValidTransition[1][i] <== CheckByteTransitionWithCapture(1)(0, 4, 115, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 2: 1 -[13]-> 2 | Capture Group: []
        isValidTransition[2][i] <== CheckByteTransitionWithCapture(1)(1, 2, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 3: 2 -[10]-> 3 | Capture Group: []
        isValidTransition[3][i] <== CheckByteTransitionWithCapture(1)(2, 3, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 4: 3 -[115]-> 4 | Capture Group: []
        isValidTransition[4][i] <== CheckByteTransitionWithCapture(1)(3, 4, 115, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 5: 4 -[117]-> 5 | Capture Group: []
        isValidTransition[5][i] <== CheckByteTransitionWithCapture(1)(4, 5, 117, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 6: 5 -[98]-> 6 | Capture Group: []
        isValidTransition[6][i] <== CheckByteTransitionWithCapture(1)(5, 6, 98, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 7: 6 -[106]-> 7 | Capture Group: []
        isValidTransition[7][i] <== CheckByteTransitionWithCapture(1)(6, 7, 106, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 8: 7 -[101]-> 8 | Capture Group: []
        isValidTransition[8][i] <== CheckByteTransitionWithCapture(1)(7, 8, 101, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 9: 8 -[99]-> 9 | Capture Group: []
        isValidTransition[9][i] <== CheckByteTransitionWithCapture(1)(8, 9, 99, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 10: 9 -[116]-> 10 | Capture Group: []
        isValidTransition[10][i] <== CheckByteTransitionWithCapture(1)(9, 10, 116, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 11: 10 -[58]-> 11 | Capture Group: []
        isValidTransition[11][i] <== CheckByteTransitionWithCapture(1)(10, 11, 58, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 12: 11 -[194-223]-> 12 | Capture Group:[ (1, 1)]
        isValidTransition[12][i] <== CheckByteRangeTransitionWithCapture(1)(11, 12, 194, 223, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 13: 11 -[224]-> 13 | Capture Group:[ (1, 1)]
        isValidTransition[13][i] <== CheckByteTransitionWithCapture(1)(11, 13, 224, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 14: 11 -[225-236]-> 14 | Capture Group:[ (1, 1)]
        isValidTransition[14][i] <== CheckByteRangeTransitionWithCapture(1)(11, 14, 225, 236, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 15: 11 -[238-239]-> 14 | Capture Group:[ (1, 1)]
        isValidTransition[15][i] <== CheckByteRangeTransitionWithCapture(1)(11, 14, 238, 239, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 16: 11 -[237]-> 15 | Capture Group:[ (1, 1)]
        isValidTransition[16][i] <== CheckByteTransitionWithCapture(1)(11, 15, 237, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 17: 11 -[240]-> 16 | Capture Group:[ (1, 1)]
        isValidTransition[17][i] <== CheckByteTransitionWithCapture(1)(11, 16, 240, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 18: 11 -[241-243]-> 17 | Capture Group:[ (1, 1)]
        isValidTransition[18][i] <== CheckByteRangeTransitionWithCapture(1)(11, 17, 241, 243, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 19: 11 -[244]-> 18 | Capture Group:[ (1, 1)]
        isValidTransition[19][i] <== CheckByteTransitionWithCapture(1)(11, 18, 244, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 20: 11 -[0-9]-> 19 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture(1)(11, 19, 0, 9, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 21: 11 -[11-12]-> 19 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[21][i] <== CheckByteRangeTransitionWithCapture(1)(11, 19, 11, 12, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 22: 11 -[14-127]-> 19 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture(1)(11, 19, 14, 127, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 23: 12 -[128-191]-> 19 | Capture Group:[ (1, 0)]
        isValidTransition[23][i] <== CheckByteRangeTransitionWithCapture(1)(12, 19, 128, 191, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 24: 13 -[160-191]-> 12 | Capture Group: []
        isValidTransition[24][i] <== CheckByteRangeTransitionWithCapture(1)(13, 12, 160, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 25: 14 -[128-191]-> 12 | Capture Group: []
        isValidTransition[25][i] <== CheckByteRangeTransitionWithCapture(1)(14, 12, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 26: 15 -[128-159]-> 12 | Capture Group: []
        isValidTransition[26][i] <== CheckByteRangeTransitionWithCapture(1)(15, 12, 128, 159, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 27: 16 -[144-191]-> 14 | Capture Group: []
        isValidTransition[27][i] <== CheckByteRangeTransitionWithCapture(1)(16, 14, 144, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 28: 17 -[128-191]-> 14 | Capture Group: []
        isValidTransition[28][i] <== CheckByteRangeTransitionWithCapture(1)(17, 14, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 29: 18 -[128-143]-> 14 | Capture Group: []
        isValidTransition[29][i] <== CheckByteRangeTransitionWithCapture(1)(18, 14, 128, 143, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 30: 19 -[194-223]-> 12 | Capture Group: []
        isValidTransition[30][i] <== CheckByteRangeTransitionWithCapture(1)(19, 12, 194, 223, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 31: 19 -[224]-> 13 | Capture Group: []
        isValidTransition[31][i] <== CheckByteTransitionWithCapture(1)(19, 13, 224, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 32: 19 -[225-236]-> 14 | Capture Group: []
        isValidTransition[32][i] <== CheckByteRangeTransitionWithCapture(1)(19, 14, 225, 236, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 33: 19 -[238-239]-> 14 | Capture Group: []
        isValidTransition[33][i] <== CheckByteRangeTransitionWithCapture(1)(19, 14, 238, 239, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 34: 19 -[237]-> 15 | Capture Group: []
        isValidTransition[34][i] <== CheckByteTransitionWithCapture(1)(19, 15, 237, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 35: 19 -[240]-> 16 | Capture Group: []
        isValidTransition[35][i] <== CheckByteTransitionWithCapture(1)(19, 16, 240, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 36: 19 -[241-243]-> 17 | Capture Group: []
        isValidTransition[36][i] <== CheckByteRangeTransitionWithCapture(1)(19, 17, 241, 243, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 37: 19 -[244]-> 18 | Capture Group: []
        isValidTransition[37][i] <== CheckByteTransitionWithCapture(1)(19, 18, 244, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 38: 19 -[0-9]-> 19 | Capture Group:[ (1, 0)]
        isValidTransition[38][i] <== CheckByteRangeTransitionWithCapture(1)(19, 19, 0, 9, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 39: 19 -[11-12]-> 19 | Capture Group:[ (1, 0)]
        isValidTransition[39][i] <== CheckByteRangeTransitionWithCapture(1)(19, 19, 11, 12, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 40: 19 -[14-127]-> 19 | Capture Group:[ (1, 0)]
        isValidTransition[40][i] <== CheckByteRangeTransitionWithCapture(1)(19, 19, 14, 127, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 41: 19 -[13]-> 20 | Capture Group: []
        isValidTransition[41][i] <== CheckByteTransitionWithCapture(1)(19, 20, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 42: 20 -[10]-> 21 | Capture Group: []
        isValidTransition[42][i] <== CheckByteTransitionWithCapture(1)(20, 21, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);

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
