pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (?:\r\n|^)message-id:(<[A-Za-z0-9=@\\.\\+_-]+>)\r\n
template MessageIdRegex(maxHaystackBytes, maxMatchBytes) {
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
    var numTransitions = 33;
    var startStates[numStartStates] = [0, 1, 3];
    var acceptStates[numAcceptStates] = [19];

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
        // Transition 1: 0 -[109]-> 4 | Capture Group: []
        isValidTransition[1][i] <== CheckByteTransitionWithCapture(1)(0, 4, 109, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 2: 1 -[13]-> 2 | Capture Group: []
        isValidTransition[2][i] <== CheckByteTransitionWithCapture(1)(1, 2, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 3: 2 -[10]-> 3 | Capture Group: []
        isValidTransition[3][i] <== CheckByteTransitionWithCapture(1)(2, 3, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 4: 3 -[109]-> 4 | Capture Group: []
        isValidTransition[4][i] <== CheckByteTransitionWithCapture(1)(3, 4, 109, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 5: 4 -[101]-> 5 | Capture Group: []
        isValidTransition[5][i] <== CheckByteTransitionWithCapture(1)(4, 5, 101, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 6: 5 -[115]-> 6 | Capture Group: []
        isValidTransition[6][i] <== CheckByteTransitionWithCapture(1)(5, 6, 115, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 7: 6 -[115]-> 7 | Capture Group: []
        isValidTransition[7][i] <== CheckByteTransitionWithCapture(1)(6, 7, 115, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 8: 7 -[97]-> 8 | Capture Group: []
        isValidTransition[8][i] <== CheckByteTransitionWithCapture(1)(7, 8, 97, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 9: 8 -[103]-> 9 | Capture Group: []
        isValidTransition[9][i] <== CheckByteTransitionWithCapture(1)(8, 9, 103, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 10: 9 -[101]-> 10 | Capture Group: []
        isValidTransition[10][i] <== CheckByteTransitionWithCapture(1)(9, 10, 101, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 11: 10 -[45]-> 11 | Capture Group: []
        isValidTransition[11][i] <== CheckByteTransitionWithCapture(1)(10, 11, 45, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 12: 11 -[105]-> 12 | Capture Group: []
        isValidTransition[12][i] <== CheckByteTransitionWithCapture(1)(11, 12, 105, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 13: 12 -[100]-> 13 | Capture Group: []
        isValidTransition[13][i] <== CheckByteTransitionWithCapture(1)(12, 13, 100, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 14: 13 -[58]-> 14 | Capture Group: []
        isValidTransition[14][i] <== CheckByteTransitionWithCapture(1)(13, 14, 58, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 15: 14 -[60]-> 15 | Capture Group:[ (1, 1)]
        isValidTransition[15][i] <== CheckByteTransitionWithCapture(1)(14, 15, 60, [1], [1], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 16: 15 -[43]-> 16 | Capture Group: []
        isValidTransition[16][i] <== CheckByteTransitionWithCapture(1)(15, 16, 43, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 17: 15 -[45-46]-> 16 | Capture Group: []
        isValidTransition[17][i] <== CheckByteRangeTransitionWithCapture(1)(15, 16, 45, 46, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 18: 15 -[48-57]-> 16 | Capture Group: []
        isValidTransition[18][i] <== CheckByteRangeTransitionWithCapture(1)(15, 16, 48, 57, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 19: 15 -[61]-> 16 | Capture Group: []
        isValidTransition[19][i] <== CheckByteTransitionWithCapture(1)(15, 16, 61, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 20: 15 -[64-90]-> 16 | Capture Group: []
        isValidTransition[20][i] <== CheckByteRangeTransitionWithCapture(1)(15, 16, 64, 90, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 21: 15 -[95]-> 16 | Capture Group: []
        isValidTransition[21][i] <== CheckByteTransitionWithCapture(1)(15, 16, 95, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 22: 15 -[97-122]-> 16 | Capture Group: []
        isValidTransition[22][i] <== CheckByteRangeTransitionWithCapture(1)(15, 16, 97, 122, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 23: 16 -[43]-> 16 | Capture Group: []
        isValidTransition[23][i] <== CheckByteTransitionWithCapture(1)(16, 16, 43, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 24: 16 -[45-46]-> 16 | Capture Group: []
        isValidTransition[24][i] <== CheckByteRangeTransitionWithCapture(1)(16, 16, 45, 46, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 25: 16 -[48-57]-> 16 | Capture Group: []
        isValidTransition[25][i] <== CheckByteRangeTransitionWithCapture(1)(16, 16, 48, 57, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 26: 16 -[61]-> 16 | Capture Group: []
        isValidTransition[26][i] <== CheckByteTransitionWithCapture(1)(16, 16, 61, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 27: 16 -[64-90]-> 16 | Capture Group: []
        isValidTransition[27][i] <== CheckByteRangeTransitionWithCapture(1)(16, 16, 64, 90, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 28: 16 -[95]-> 16 | Capture Group: []
        isValidTransition[28][i] <== CheckByteTransitionWithCapture(1)(16, 16, 95, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 29: 16 -[97-122]-> 16 | Capture Group: []
        isValidTransition[29][i] <== CheckByteRangeTransitionWithCapture(1)(16, 16, 97, 122, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 30: 16 -[62]-> 17 | Capture Group:[ (1, 0)]
        isValidTransition[30][i] <== CheckByteTransitionWithCapture(1)(16, 17, 62, [1], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 31: 17 -[13]-> 18 | Capture Group: []
        isValidTransition[31][i] <== CheckByteTransitionWithCapture(1)(17, 18, 13, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);
        // Transition 32: 18 -[10]-> 19 | Capture Group: []
        isValidTransition[32][i] <== CheckByteTransitionWithCapture(1)(18, 19, 10, [0], [0], currStates[i], nextStates[i], haystack[i], [captureGroup1Id[i]], [captureGroup1Start[i]]);

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
    signal output capture1[128] <== CaptureSubstring(maxMatchBytes, 128, 1)(captureGroupStartIndices[0], haystack, captureGroup1Id, captureGroup1Start);
}
