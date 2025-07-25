pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";

// regex: (?:\r\n|^)from:([^\r\n]+)\r\n
template FromAllRegex(maxHaystackBytes, maxMatchBytes) {
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
    var numTransitions = 40;
    var startStates[numStartStates] = [0, 1, 3];
    var acceptStates[numAcceptStates] = [18];

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
        // Transition 1: 0 -[102]-> 4 | Capture Group: []
        isValidTransition[1][i] <== CheckByteTransitionWithCapture(1)(0, 4, 102, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 2: 1 -[13]-> 2 | Capture Group: []
        isValidTransition[2][i] <== CheckByteTransitionWithCapture(1)(1, 2, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 3: 2 -[10]-> 3 | Capture Group: []
        isValidTransition[3][i] <== CheckByteTransitionWithCapture(1)(2, 3, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 4: 3 -[102]-> 4 | Capture Group: []
        isValidTransition[4][i] <== CheckByteTransitionWithCapture(1)(3, 4, 102, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 5: 4 -[114]-> 5 | Capture Group: []
        isValidTransition[5][i] <== CheckByteTransitionWithCapture(1)(4, 5, 114, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 6: 5 -[111]-> 6 | Capture Group: []
        isValidTransition[6][i] <== CheckByteTransitionWithCapture(1)(5, 6, 111, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 7: 6 -[109]-> 7 | Capture Group: []
        isValidTransition[7][i] <== CheckByteTransitionWithCapture(1)(6, 7, 109, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 8: 7 -[58]-> 8 | Capture Group: []
        isValidTransition[8][i] <== CheckByteTransitionWithCapture(1)(7, 8, 58, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 9: 8 -[194-223]-> 9 | Capture Group:[ (1, 1)]
        isValidTransition[9][i] <== CheckByteRangeTransitionWithCapture(1)(8, 9, 194, 223, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 10: 8 -[224]-> 10 | Capture Group:[ (1, 1)]
        isValidTransition[10][i] <== CheckByteTransitionWithCapture(1)(8, 10, 224, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 11: 8 -[225-236]-> 11 | Capture Group:[ (1, 1)]
        isValidTransition[11][i] <== CheckByteRangeTransitionWithCapture(1)(8, 11, 225, 236, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 12: 8 -[238-239]-> 11 | Capture Group:[ (1, 1)]
        isValidTransition[12][i] <== CheckByteRangeTransitionWithCapture(1)(8, 11, 238, 239, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 13: 8 -[237]-> 12 | Capture Group:[ (1, 1)]
        isValidTransition[13][i] <== CheckByteTransitionWithCapture(1)(8, 12, 237, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 14: 8 -[240]-> 13 | Capture Group:[ (1, 1)]
        isValidTransition[14][i] <== CheckByteTransitionWithCapture(1)(8, 13, 240, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 15: 8 -[241-243]-> 14 | Capture Group:[ (1, 1)]
        isValidTransition[15][i] <== CheckByteRangeTransitionWithCapture(1)(8, 14, 241, 243, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 16: 8 -[244]-> 15 | Capture Group:[ (1, 1)]
        isValidTransition[16][i] <== CheckByteTransitionWithCapture(1)(8, 15, 244, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 17: 8 -[0-9]-> 16 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[17][i] <== CheckByteRangeTransitionWithCapture(1)(8, 16, 0, 9, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 18: 8 -[11-12]-> 16 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[18][i] <== CheckByteRangeTransitionWithCapture(1)(8, 16, 11, 12, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 19: 8 -[14-127]-> 16 | Capture Group:[ (1, 0), (1, 1)]
        isValidTransition[19][i] <== CheckByteRangeTransitionWithCapture(1)(8, 16, 14, 127, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 20: 9 -[128-191]-> 16 | Capture Group:[ (1, 0)]
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture(1)(9, 16, 128, 191, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 21: 10 -[160-191]-> 9 | Capture Group: []
        isValidTransition[21][i] <== CheckByteRangeTransitionWithCapture(1)(10, 9, 160, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 22: 11 -[128-191]-> 9 | Capture Group: []
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture(1)(11, 9, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 23: 12 -[128-159]-> 9 | Capture Group: []
        isValidTransition[23][i] <== CheckByteRangeTransitionWithCapture(1)(12, 9, 128, 159, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 24: 13 -[144-191]-> 11 | Capture Group: []
        isValidTransition[24][i] <== CheckByteRangeTransitionWithCapture(1)(13, 11, 144, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 25: 14 -[128-191]-> 11 | Capture Group: []
        isValidTransition[25][i] <== CheckByteRangeTransitionWithCapture(1)(14, 11, 128, 191, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 26: 15 -[128-143]-> 11 | Capture Group: []
        isValidTransition[26][i] <== CheckByteRangeTransitionWithCapture(1)(15, 11, 128, 143, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 27: 16 -[194-223]-> 9 | Capture Group: []
        isValidTransition[27][i] <== CheckByteRangeTransitionWithCapture(1)(16, 9, 194, 223, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 28: 16 -[224]-> 10 | Capture Group: []
        isValidTransition[28][i] <== CheckByteTransitionWithCapture(1)(16, 10, 224, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 29: 16 -[225-236]-> 11 | Capture Group: []
        isValidTransition[29][i] <== CheckByteRangeTransitionWithCapture(1)(16, 11, 225, 236, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 30: 16 -[238-239]-> 11 | Capture Group: []
        isValidTransition[30][i] <== CheckByteRangeTransitionWithCapture(1)(16, 11, 238, 239, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 31: 16 -[237]-> 12 | Capture Group: []
        isValidTransition[31][i] <== CheckByteTransitionWithCapture(1)(16, 12, 237, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 32: 16 -[240]-> 13 | Capture Group: []
        isValidTransition[32][i] <== CheckByteTransitionWithCapture(1)(16, 13, 240, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 33: 16 -[241-243]-> 14 | Capture Group: []
        isValidTransition[33][i] <== CheckByteRangeTransitionWithCapture(1)(16, 14, 241, 243, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 34: 16 -[244]-> 15 | Capture Group: []
        isValidTransition[34][i] <== CheckByteTransitionWithCapture(1)(16, 15, 244, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 35: 16 -[0-9]-> 16 | Capture Group:[ (1, 0)]
        isValidTransition[35][i] <== CheckByteRangeTransitionWithCapture(1)(16, 16, 0, 9, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 36: 16 -[11-12]-> 16 | Capture Group:[ (1, 0)]
        isValidTransition[36][i] <== CheckByteRangeTransitionWithCapture(1)(16, 16, 11, 12, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 37: 16 -[14-127]-> 16 | Capture Group:[ (1, 0)]
        isValidTransition[37][i] <== CheckByteRangeTransitionWithCapture(1)(16, 16, 14, 127, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 38: 16 -[13]-> 17 | Capture Group: []
        isValidTransition[38][i] <== CheckByteTransitionWithCapture(1)(16, 17, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 39: 17 -[10]-> 18 | Capture Group: []
        isValidTransition[39][i] <== CheckByteTransitionWithCapture(1)(17, 18, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);

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
