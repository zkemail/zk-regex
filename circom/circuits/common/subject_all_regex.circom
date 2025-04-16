pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";
include "@zk-email/circuits/utils/array.circom";

// regex: (?:\r\n|^)subject:([a-z]+)\r\n
template SubjectAllRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input captureGroupIds[maxMatchBytes];
    signal input captureGroupStarts[maxMatchBytes];
    signal input traversalPathLength;

    signal output isValid;

    var numStartStates = 3;
    var numAcceptStates = 1;
    var numTransitions = 16;
    var startStates[numStartStates] = [0, 1, 3];
    var acceptStates[numAcceptStates] = [14];

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
        isWithinPathLength[i] <== LessThan(log2Ceil(maxMatchBytes))([i, traversalPathLength]);

        // Check if the traversal is a valid path
        if (i < maxMatchBytes-2) {
            isWithinPathLengthMinusOne[i] <== LessThan(log2Ceil(maxMatchBytes))([i, traversalPathLength-1]);
            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);
            isTransitionLinked[i] === isWithinPathLengthMinusOne[i];
        }

        // Transition 0: 3 -[115]-> 4 | Capture Group: (0, 0)
        isValidTransition[0][i] <== CheckByteTransitionWithCapture()(3, 4, 115, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 1: 9 -[116]-> 10 | Capture Group: (0, 0)
        isValidTransition[1][i] <== CheckByteTransitionWithCapture()(9, 10, 116, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 2: 4 -[117]-> 5 | Capture Group: (0, 0)
        isValidTransition[2][i] <== CheckByteTransitionWithCapture()(4, 5, 117, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 3: 0 -[115]-> 4 | Capture Group: (0, 0)
        isValidTransition[3][i] <== CheckByteTransitionWithCapture()(0, 4, 115, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 4: 13 -[10]-> 14 | Capture Group: (0, 0)
        isValidTransition[4][i] <== CheckByteTransitionWithCapture()(13, 14, 10, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 5: 5 -[98]-> 6 | Capture Group: (0, 0)
        isValidTransition[5][i] <== CheckByteTransitionWithCapture()(5, 6, 98, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 6: 1 -[13]-> 2 | Capture Group: (0, 0)
        isValidTransition[6][i] <== CheckByteTransitionWithCapture()(1, 2, 13, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 7: 0 -[13]-> 2 | Capture Group: (0, 0)
        isValidTransition[7][i] <== CheckByteTransitionWithCapture()(0, 2, 13, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 8: 8 -[99]-> 9 | Capture Group: (0, 0)
        isValidTransition[8][i] <== CheckByteTransitionWithCapture()(8, 9, 99, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 9: 11 -[97-122]-> 12 | Capture Group: (1, 1)
        isValidTransition[9][i] <== CheckByteRangeTransitionWithCapture()(11, 12, 97, 122, 1, 1, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 10: 7 -[101]-> 8 | Capture Group: (0, 0)
        isValidTransition[10][i] <== CheckByteTransitionWithCapture()(7, 8, 101, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 11: 2 -[10]-> 3 | Capture Group: (0, 0)
        isValidTransition[11][i] <== CheckByteTransitionWithCapture()(2, 3, 10, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 12: 10 -[58]-> 11 | Capture Group: (0, 0)
        isValidTransition[12][i] <== CheckByteTransitionWithCapture()(10, 11, 58, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 13: 12 -[13]-> 13 | Capture Group: (1, 0)
        isValidTransition[13][i] <== CheckByteTransitionWithCapture()(12, 13, 13, 1, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 14: 12 -[97-122]-> 12 | Capture Group: (0, 0)
        isValidTransition[14][i] <== CheckByteRangeTransitionWithCapture()(12, 12, 97, 122, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);
        // Transition 15: 6 -[106]-> 7 | Capture Group: (0, 0)
        isValidTransition[15][i] <== CheckByteTransitionWithCapture()(6, 7, 106, 0, 0, currStates[i], nextStates[i], haystack[i], captureGroupIds[i], captureGroupStarts[i]);

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

    isValid <== isValidRegex[maxMatchBytes-1];

    // Capture Group 1
    signal input capture1StartIndex;
    signal output capture1[64] <== CaptureSubstring(maxMatchBytes, 64, 1)(capture1StartIndex, haystack, captureGroupIds, captureGroupStarts);
}
