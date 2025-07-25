pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";

// regex: ([A-Za-z0-9!#$%&\'*+=?\\-\\^_`{|}~./@]+@[A-Za-z0-9.\\-]+)
template EmailAddrRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input captureGroup1Id[maxMatchBytes];
    signal input captureGroup1Start[maxMatchBytes];
    signal output isValid;

    var numStartStates = 1;
    var numAcceptStates = 1;
    var numTransitions = 23;
    var startStates[numStartStates] = [0];
    var acceptStates[numAcceptStates] = [3];

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
            isTransitionLinked[i] === isWithinPathLengthMinusOne[i];
        }

        // Transition 0: 0 -[33]-> 1 | Capture Group:[ (1, 1)]
        isValidTransition[0][i] <== CheckByteTransitionWithCapture(1)(0, 1, 33, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 1: 0 -[35-39]-> 1 | Capture Group:[ (1, 1)]
        isValidTransition[1][i] <== CheckByteRangeTransitionWithCapture(1)(0, 1, 35, 39, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 2: 0 -[42-43]-> 1 | Capture Group:[ (1, 1)]
        isValidTransition[2][i] <== CheckByteRangeTransitionWithCapture(1)(0, 1, 42, 43, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 3: 0 -[45-57]-> 1 | Capture Group:[ (1, 1)]
        isValidTransition[3][i] <== CheckByteRangeTransitionWithCapture(1)(0, 1, 45, 57, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 4: 0 -[61]-> 1 | Capture Group:[ (1, 1)]
        isValidTransition[4][i] <== CheckByteTransitionWithCapture(1)(0, 1, 61, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 5: 0 -[63-90]-> 1 | Capture Group:[ (1, 1)]
        isValidTransition[5][i] <== CheckByteRangeTransitionWithCapture(1)(0, 1, 63, 90, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 6: 0 -[94-126]-> 1 | Capture Group:[ (1, 1)]
        isValidTransition[6][i] <== CheckByteRangeTransitionWithCapture(1)(0, 1, 94, 126, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 7: 1 -[33]-> 1 | Capture Group: []
        isValidTransition[7][i] <== CheckByteTransitionWithCapture(1)(1, 1, 33, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 8: 1 -[35-39]-> 1 | Capture Group: []
        isValidTransition[8][i] <== CheckByteRangeTransitionWithCapture(1)(1, 1, 35, 39, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 9: 1 -[42-43]-> 1 | Capture Group: []
        isValidTransition[9][i] <== CheckByteRangeTransitionWithCapture(1)(1, 1, 42, 43, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 10: 1 -[45-57]-> 1 | Capture Group: []
        isValidTransition[10][i] <== CheckByteRangeTransitionWithCapture(1)(1, 1, 45, 57, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 11: 1 -[61]-> 1 | Capture Group: []
        isValidTransition[11][i] <== CheckByteTransitionWithCapture(1)(1, 1, 61, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 12: 1 -[63-90]-> 1 | Capture Group: []
        isValidTransition[12][i] <== CheckByteRangeTransitionWithCapture(1)(1, 1, 63, 90, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 13: 1 -[94-126]-> 1 | Capture Group: []
        isValidTransition[13][i] <== CheckByteRangeTransitionWithCapture(1)(1, 1, 94, 126, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 14: 1 -[64]-> 2 | Capture Group: []
        isValidTransition[14][i] <== CheckByteTransitionWithCapture(1)(1, 2, 64, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 15: 2 -[45-46]-> 3 | Capture Group:[ (1, 0)]
        isValidTransition[15][i] <== CheckByteRangeTransitionWithCapture(1)(2, 3, 45, 46, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 16: 2 -[48-57]-> 3 | Capture Group:[ (1, 0)]
        isValidTransition[16][i] <== CheckByteRangeTransitionWithCapture(1)(2, 3, 48, 57, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 17: 2 -[65-90]-> 3 | Capture Group:[ (1, 0)]
        isValidTransition[17][i] <== CheckByteRangeTransitionWithCapture(1)(2, 3, 65, 90, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 18: 2 -[97-122]-> 3 | Capture Group:[ (1, 0)]
        isValidTransition[18][i] <== CheckByteRangeTransitionWithCapture(1)(2, 3, 97, 122, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 19: 3 -[45-46]-> 3 | Capture Group:[ (1, 0)]
        isValidTransition[19][i] <== CheckByteRangeTransitionWithCapture(1)(3, 3, 45, 46, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 20: 3 -[48-57]-> 3 | Capture Group:[ (1, 0)]
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture(1)(3, 3, 48, 57, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 21: 3 -[65-90]-> 3 | Capture Group:[ (1, 0)]
        isValidTransition[21][i] <== CheckByteRangeTransitionWithCapture(1)(3, 3, 65, 90, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 22: 3 -[97-122]-> 3 | Capture Group:[ (1, 0)]
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture(1)(3, 3, 97, 122, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);

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
    signal output capture1[320] <== CaptureSubstring(maxMatchBytes, 320, 1)(captureGroupStartIndices[0], haystack, captureGroup1Id, captureGroup1Start);
}
