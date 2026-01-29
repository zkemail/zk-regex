pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (.)_(.+)
template MixedCaptureLengthRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input captureGroup1Id[maxMatchBytes];
    signal input captureGroup2Id[maxMatchBytes];
    signal input captureGroup1Start[maxMatchBytes];
    signal input captureGroup2Start[maxMatchBytes];
    signal output isValid;

    var numStartStates = 1;
    var numAcceptStates = 1;
    var numTransitions = 45;
    var startStates[numStartStates] = [0];
    var acceptStates[numAcceptStates] = [17];

    signal isCurrentState[numTransitions][maxMatchBytes];
    signal isNextState[numTransitions][maxMatchBytes];
    signal isValidTransition[numTransitions][maxMatchBytes];
    signal reachedLastTransition[maxMatchBytes];
    signal isValidRegex[maxMatchBytes];
    signal isValidRegexTemp[maxMatchBytes];
    signal isWithinPathLength[maxMatchBytes];
    signal isWithinPathLengthMinusOne[maxMatchBytes-2];
    signal isTransitionLinked[maxMatchBytes];

    signal isValidStartState;

    signal reachedAcceptState[maxMatchBytes];

    component isValidTraversal[maxMatchBytes];

    // Select the haystack from the input
    signal haystack[maxMatchBytes] <== SelectSubArray(maxHaystackBytes, maxMatchBytes)(inHaystack, matchStart, matchLength);

    // Check if the first state in the haystack is a valid start state
    isValidStartState <== IsEqual()([startStates[0], currStates[0]]);

    for (var i = 0; i < maxMatchBytes; i++) {
        isWithinPathLength[i] <== LessThan(log2Ceil(maxMatchBytes))([i, matchLength]);

        // Check if the traversal is a valid path
        if (i < maxMatchBytes-2) {
            isWithinPathLengthMinusOne[i] <== LessThan(log2Ceil(maxMatchBytes))([i, matchLength-1]);
            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);
            isTransitionLinked[i] * isWithinPathLengthMinusOne[i] === isWithinPathLengthMinusOne[i];
        }

        // Transition 0: 0 -[194-223]-> 1 | Capture Group:[ (1, 1)]
        isValidTransition[0][i] <== CheckByteRangeTransitionWithCapture(2)(0, 1, 194, 223, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 1: 0 -[224]-> 2 | Capture Group:[ (1, 1)]
        isValidTransition[1][i] <== CheckByteTransitionWithCapture(2)(0, 2, 224, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 2: 0 -[225-236]-> 3 | Capture Group:[ (1, 1)]
        isValidTransition[2][i] <== CheckByteRangeTransitionWithCapture(2)(0, 3, 225, 236, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 3: 0 -[238-239]-> 3 | Capture Group:[ (1, 1)]
        isValidTransition[3][i] <== CheckByteRangeTransitionWithCapture(2)(0, 3, 238, 239, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 4: 0 -[237]-> 4 | Capture Group:[ (1, 1)]
        isValidTransition[4][i] <== CheckByteTransitionWithCapture(2)(0, 4, 237, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 5: 0 -[240]-> 5 | Capture Group:[ (1, 1)]
        isValidTransition[5][i] <== CheckByteTransitionWithCapture(2)(0, 5, 240, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 6: 0 -[241-243]-> 6 | Capture Group:[ (1, 1)]
        isValidTransition[6][i] <== CheckByteRangeTransitionWithCapture(2)(0, 6, 241, 243, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 7: 0 -[244]-> 7 | Capture Group:[ (1, 1)]
        isValidTransition[7][i] <== CheckByteTransitionWithCapture(2)(0, 7, 244, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 8: 0 -[0-9]-> 8 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[8][i] <== CheckByteRangeTransitionWithCapture(2)(0, 8, 0, 9, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 9: 0 -[11-127]-> 8 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[9][i] <== CheckByteRangeTransitionWithCapture(2)(0, 8, 11, 127, [1, 0], [1, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 10: 1 -[128-191]-> 8 | Capture Group:[ (1, 0)]
        isValidTransition[10][i] <== CheckByteRangeTransitionWithCapture(2)(1, 8, 128, 191, [1, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 11: 2 -[160-191]-> 1 | Capture Group: []
        isValidTransition[11][i] <== CheckByteRangeTransitionWithCapture(2)(2, 1, 160, 191, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 12: 3 -[128-191]-> 1 | Capture Group: []
        isValidTransition[12][i] <== CheckByteRangeTransitionWithCapture(2)(3, 1, 128, 191, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 13: 4 -[128-159]-> 1 | Capture Group: []
        isValidTransition[13][i] <== CheckByteRangeTransitionWithCapture(2)(4, 1, 128, 159, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 14: 5 -[144-191]-> 3 | Capture Group: []
        isValidTransition[14][i] <== CheckByteRangeTransitionWithCapture(2)(5, 3, 144, 191, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 15: 6 -[128-191]-> 3 | Capture Group: []
        isValidTransition[15][i] <== CheckByteRangeTransitionWithCapture(2)(6, 3, 128, 191, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 16: 7 -[128-143]-> 3 | Capture Group: []
        isValidTransition[16][i] <== CheckByteRangeTransitionWithCapture(2)(7, 3, 128, 143, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 17: 8 -[95]-> 9 | Capture Group: []
        isValidTransition[17][i] <== CheckByteTransitionWithCapture(2)(8, 9, 95, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 18: 9 -[194-223]-> 10 | Capture Group:[ (2, 1)]
        isValidTransition[18][i] <== CheckByteRangeTransitionWithCapture(2)(9, 10, 194, 223, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 19: 9 -[224]-> 11 | Capture Group:[ (2, 1)]
        isValidTransition[19][i] <== CheckByteTransitionWithCapture(2)(9, 11, 224, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 20: 9 -[225-236]-> 12 | Capture Group:[ (2, 1)]
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture(2)(9, 12, 225, 236, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 21: 9 -[238-239]-> 12 | Capture Group:[ (2, 1)]
        isValidTransition[21][i] <== CheckByteRangeTransitionWithCapture(2)(9, 12, 238, 239, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 22: 9 -[237]-> 13 | Capture Group:[ (2, 1)]
        isValidTransition[22][i] <== CheckByteTransitionWithCapture(2)(9, 13, 237, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 23: 9 -[240]-> 14 | Capture Group:[ (2, 1)]
        isValidTransition[23][i] <== CheckByteTransitionWithCapture(2)(9, 14, 240, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 24: 9 -[241-243]-> 15 | Capture Group:[ (2, 1)]
        isValidTransition[24][i] <== CheckByteRangeTransitionWithCapture(2)(9, 15, 241, 243, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 25: 9 -[244]-> 16 | Capture Group:[ (2, 1)]
        isValidTransition[25][i] <== CheckByteTransitionWithCapture(2)(9, 16, 244, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 26: 9 -[0-9]-> 17 | Capture Group:[ (2, 0), (2, 1)]
        isValidTransition[26][i] <== CheckByteRangeTransitionWithCapture(2)(9, 17, 0, 9, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 27: 9 -[11-127]-> 17 | Capture Group:[ (2, 0), (2, 1)]
        isValidTransition[27][i] <== CheckByteRangeTransitionWithCapture(2)(9, 17, 11, 127, [0, 2], [0, 1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 28: 10 -[128-191]-> 17 | Capture Group:[ (2, 0)]
        isValidTransition[28][i] <== CheckByteRangeTransitionWithCapture(2)(10, 17, 128, 191, [0, 2], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 29: 11 -[160-191]-> 10 | Capture Group: []
        isValidTransition[29][i] <== CheckByteRangeTransitionWithCapture(2)(11, 10, 160, 191, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 30: 12 -[128-191]-> 10 | Capture Group: []
        isValidTransition[30][i] <== CheckByteRangeTransitionWithCapture(2)(12, 10, 128, 191, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 31: 13 -[128-159]-> 10 | Capture Group: []
        isValidTransition[31][i] <== CheckByteRangeTransitionWithCapture(2)(13, 10, 128, 159, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 32: 14 -[144-191]-> 12 | Capture Group: []
        isValidTransition[32][i] <== CheckByteRangeTransitionWithCapture(2)(14, 12, 144, 191, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 33: 15 -[128-191]-> 12 | Capture Group: []
        isValidTransition[33][i] <== CheckByteRangeTransitionWithCapture(2)(15, 12, 128, 191, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 34: 16 -[128-143]-> 12 | Capture Group: []
        isValidTransition[34][i] <== CheckByteRangeTransitionWithCapture(2)(16, 12, 128, 143, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 35: 17 -[194-223]-> 10 | Capture Group: []
        isValidTransition[35][i] <== CheckByteRangeTransitionWithCapture(2)(17, 10, 194, 223, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 36: 17 -[224]-> 11 | Capture Group: []
        isValidTransition[36][i] <== CheckByteTransitionWithCapture(2)(17, 11, 224, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 37: 17 -[225-236]-> 12 | Capture Group: []
        isValidTransition[37][i] <== CheckByteRangeTransitionWithCapture(2)(17, 12, 225, 236, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 38: 17 -[238-239]-> 12 | Capture Group: []
        isValidTransition[38][i] <== CheckByteRangeTransitionWithCapture(2)(17, 12, 238, 239, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 39: 17 -[237]-> 13 | Capture Group: []
        isValidTransition[39][i] <== CheckByteTransitionWithCapture(2)(17, 13, 237, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 40: 17 -[240]-> 14 | Capture Group: []
        isValidTransition[40][i] <== CheckByteTransitionWithCapture(2)(17, 14, 240, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 41: 17 -[241-243]-> 15 | Capture Group: []
        isValidTransition[41][i] <== CheckByteRangeTransitionWithCapture(2)(17, 15, 241, 243, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 42: 17 -[244]-> 16 | Capture Group: []
        isValidTransition[42][i] <== CheckByteTransitionWithCapture(2)(17, 16, 244, [0, 0], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 43: 17 -[0-9]-> 17 | Capture Group:[ (2, 0)]
        isValidTransition[43][i] <== CheckByteRangeTransitionWithCapture(2)(17, 17, 0, 9, [0, 2], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);
        // Transition 44: 17 -[11-127]-> 17 | Capture Group:[ (2, 0)]
        isValidTransition[44][i] <== CheckByteRangeTransitionWithCapture(2)(17, 17, 11, 127, [0, 2], [0, 0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i], captureGroup2Id[i]], [captureGroup1Start[i], captureGroup2Start[i]]);

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

    signal input captureGroupStartIndices[2];

    // Capture Group 1
    signal output capture1[1] <== CaptureSubstring(maxMatchBytes, 1, 1)(captureGroupStartIndices[0], haystack, captureGroup1Id, captureGroup1Start);
    // Capture Group 2
    signal output capture2[64] <== CaptureSubstring(maxMatchBytes, 64, 2)(captureGroupStartIndices[1], haystack, captureGroup2Id, captureGroup2Start);
}
