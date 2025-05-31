pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";

// regex: (?:\r\n|^)to:([^\r\n]+)\r\n
template ToAllRegex(maxHaystackBytes, maxMatchBytes) {
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
    var numTransitions = 38;
    var startStates[numStartStates] = [0, 1, 3];
    var acceptStates[numAcceptStates] = [16];

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

        // Transition 0: 0 -[13]-> 2 | Capture Group: []
        isValidTransition[0][i] <== CheckByteTransitionWithCapture(1)(0, 2, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 1: 0 -[116]-> 4 | Capture Group: []
        isValidTransition[1][i] <== CheckByteTransitionWithCapture(1)(0, 4, 116, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 2: 1 -[13]-> 2 | Capture Group: []
        isValidTransition[2][i] <== CheckByteTransitionWithCapture(1)(1, 2, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 3: 2 -[10]-> 3 | Capture Group: []
        isValidTransition[3][i] <== CheckByteTransitionWithCapture(1)(2, 3, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 4: 3 -[116]-> 4 | Capture Group: []
        isValidTransition[4][i] <== CheckByteTransitionWithCapture(1)(3, 4, 116, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 5: 4 -[111]-> 5 | Capture Group: []
        isValidTransition[5][i] <== CheckByteTransitionWithCapture(1)(4, 5, 111, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 6: 5 -[58]-> 6 | Capture Group: []
        isValidTransition[6][i] <== CheckByteTransitionWithCapture(1)(5, 6, 58, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 7: 6 -[194-223]-> 7 | Capture Group:[ (1, 1)]
        isValidTransition[7][i] <== CheckByteRangeTransitionWithCapture(1)(6, 7, 194, 223, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 8: 6 -[224]-> 8 | Capture Group:[ (1, 1)]
        isValidTransition[8][i] <== CheckByteTransitionWithCapture(1)(6, 8, 224, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 9: 6 -[225-236]-> 9 | Capture Group:[ (1, 1)]
        isValidTransition[9][i] <== CheckByteRangeTransitionWithCapture(1)(6, 9, 225, 236, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 10: 6 -[238-239]-> 9 | Capture Group:[ (1, 1)]
        isValidTransition[10][i] <== CheckByteRangeTransitionWithCapture(1)(6, 9, 238, 239, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 11: 6 -[237]-> 10 | Capture Group:[ (1, 1)]
        isValidTransition[11][i] <== CheckByteTransitionWithCapture(1)(6, 10, 237, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 12: 6 -[240]-> 11 | Capture Group:[ (1, 1)]
        isValidTransition[12][i] <== CheckByteTransitionWithCapture(1)(6, 11, 240, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 13: 6 -[241-243]-> 12 | Capture Group:[ (1, 1)]
        isValidTransition[13][i] <== CheckByteRangeTransitionWithCapture(1)(6, 12, 241, 243, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 14: 6 -[244]-> 13 | Capture Group:[ (1, 1)]
        isValidTransition[14][i] <== CheckByteTransitionWithCapture(1)(6, 13, 244, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 15: 6 -[0-9]-> 14 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[15][i] <== CheckByteRangeTransitionWithCapture(1)(6, 14, 0, 9, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 16: 6 -[11-12]-> 14 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[16][i] <== CheckByteRangeTransitionWithCapture(1)(6, 14, 11, 12, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 17: 6 -[14-127]-> 14 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[17][i] <== CheckByteRangeTransitionWithCapture(1)(6, 14, 14, 127, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 18: 7 -[128-191]-> 14 | Capture Group:[ (1, 0)]
        isValidTransition[18][i] <== CheckByteRangeTransitionWithCapture(1)(7, 14, 128, 191, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 19: 8 -[160-191]-> 7 | Capture Group: []
        isValidTransition[19][i] <== CheckByteRangeTransitionWithCapture(1)(8, 7, 160, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 20: 9 -[128-191]-> 7 | Capture Group: []
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture(1)(9, 7, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 21: 10 -[128-159]-> 7 | Capture Group: []
        isValidTransition[21][i] <== CheckByteRangeTransitionWithCapture(1)(10, 7, 128, 159, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 22: 11 -[144-191]-> 9 | Capture Group: []
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture(1)(11, 9, 144, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 23: 12 -[128-191]-> 9 | Capture Group: []
        isValidTransition[23][i] <== CheckByteRangeTransitionWithCapture(1)(12, 9, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 24: 13 -[128-143]-> 9 | Capture Group: []
        isValidTransition[24][i] <== CheckByteRangeTransitionWithCapture(1)(13, 9, 128, 143, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 25: 14 -[194-223]-> 7 | Capture Group: []
        isValidTransition[25][i] <== CheckByteRangeTransitionWithCapture(1)(14, 7, 194, 223, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 26: 14 -[224]-> 8 | Capture Group: []
        isValidTransition[26][i] <== CheckByteTransitionWithCapture(1)(14, 8, 224, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 27: 14 -[225-236]-> 9 | Capture Group: []
        isValidTransition[27][i] <== CheckByteRangeTransitionWithCapture(1)(14, 9, 225, 236, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 28: 14 -[238-239]-> 9 | Capture Group: []
        isValidTransition[28][i] <== CheckByteRangeTransitionWithCapture(1)(14, 9, 238, 239, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 29: 14 -[237]-> 10 | Capture Group: []
        isValidTransition[29][i] <== CheckByteTransitionWithCapture(1)(14, 10, 237, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 30: 14 -[240]-> 11 | Capture Group: []
        isValidTransition[30][i] <== CheckByteTransitionWithCapture(1)(14, 11, 240, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 31: 14 -[241-243]-> 12 | Capture Group: []
        isValidTransition[31][i] <== CheckByteRangeTransitionWithCapture(1)(14, 12, 241, 243, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 32: 14 -[244]-> 13 | Capture Group: []
        isValidTransition[32][i] <== CheckByteTransitionWithCapture(1)(14, 13, 244, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 33: 14 -[0-9]-> 14 | Capture Group:[ (1, 0)]
        isValidTransition[33][i] <== CheckByteRangeTransitionWithCapture(1)(14, 14, 0, 9, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 34: 14 -[11-12]-> 14 | Capture Group:[ (1, 0)]
        isValidTransition[34][i] <== CheckByteRangeTransitionWithCapture(1)(14, 14, 11, 12, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 35: 14 -[14-127]-> 14 | Capture Group:[ (1, 0)]
        isValidTransition[35][i] <== CheckByteRangeTransitionWithCapture(1)(14, 14, 14, 127, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 36: 14 -[13]-> 15 | Capture Group: []
        isValidTransition[36][i] <== CheckByteTransitionWithCapture(1)(14, 15, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 37: 15 -[10]-> 16 | Capture Group: []
        isValidTransition[37][i] <== CheckByteTransitionWithCapture(1)(15, 16, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);

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
