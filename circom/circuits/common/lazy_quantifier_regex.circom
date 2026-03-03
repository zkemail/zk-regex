pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: <.*?>
template LazyQuantifierRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal output isValid;

    var numStartStates = 2;
    var numAcceptStates = 1;
    var numTransitions = 20;
    var startStates[numStartStates] = [0, 1];
    var acceptStates[numAcceptStates] = [10];

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

        // Transition 0: 0 -[60]-> 2
        isValidTransition[0][i] <== CheckByteTransition()(0, 2, 60, currStates[i], nextStates[i], haystack[i]);
        // Transition 1: 1 -[60]-> 2
        isValidTransition[1][i] <== CheckByteTransition()(1, 2, 60, currStates[i], nextStates[i], haystack[i]);
        // Transition 2: 2 -[0-9]-> 2
        isValidTransition[2][i] <== CheckByteRangeTransition()(2, 2, 0, 9, currStates[i], nextStates[i], haystack[i]);
        // Transition 3: 2 -[11-127]-> 2
        isValidTransition[3][i] <== CheckByteRangeTransition()(2, 2, 11, 127, currStates[i], nextStates[i], haystack[i]);
        // Transition 4: 2 -[194-223]-> 3
        isValidTransition[4][i] <== CheckByteRangeTransition()(2, 3, 194, 223, currStates[i], nextStates[i], haystack[i]);
        // Transition 5: 2 -[224]-> 4
        isValidTransition[5][i] <== CheckByteTransition()(2, 4, 224, currStates[i], nextStates[i], haystack[i]);
        // Transition 6: 2 -[225-236]-> 5
        isValidTransition[6][i] <== CheckByteRangeTransition()(2, 5, 225, 236, currStates[i], nextStates[i], haystack[i]);
        // Transition 7: 2 -[238-239]-> 5
        isValidTransition[7][i] <== CheckByteRangeTransition()(2, 5, 238, 239, currStates[i], nextStates[i], haystack[i]);
        // Transition 8: 2 -[237]-> 6
        isValidTransition[8][i] <== CheckByteTransition()(2, 6, 237, currStates[i], nextStates[i], haystack[i]);
        // Transition 9: 2 -[240]-> 7
        isValidTransition[9][i] <== CheckByteTransition()(2, 7, 240, currStates[i], nextStates[i], haystack[i]);
        // Transition 10: 2 -[241-243]-> 8
        isValidTransition[10][i] <== CheckByteRangeTransition()(2, 8, 241, 243, currStates[i], nextStates[i], haystack[i]);
        // Transition 11: 2 -[244]-> 9
        isValidTransition[11][i] <== CheckByteTransition()(2, 9, 244, currStates[i], nextStates[i], haystack[i]);
        // Transition 12: 2 -[62]-> 10
        isValidTransition[12][i] <== CheckByteTransition()(2, 10, 62, currStates[i], nextStates[i], haystack[i]);
        // Transition 13: 3 -[128-191]-> 2
        isValidTransition[13][i] <== CheckByteRangeTransition()(3, 2, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 14: 4 -[160-191]-> 3
        isValidTransition[14][i] <== CheckByteRangeTransition()(4, 3, 160, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 15: 5 -[128-191]-> 3
        isValidTransition[15][i] <== CheckByteRangeTransition()(5, 3, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 16: 6 -[128-159]-> 3
        isValidTransition[16][i] <== CheckByteRangeTransition()(6, 3, 128, 159, currStates[i], nextStates[i], haystack[i]);
        // Transition 17: 7 -[144-191]-> 5
        isValidTransition[17][i] <== CheckByteRangeTransition()(7, 5, 144, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 18: 8 -[128-191]-> 5
        isValidTransition[18][i] <== CheckByteRangeTransition()(8, 5, 128, 191, currStates[i], nextStates[i], haystack[i]);
        // Transition 19: 9 -[128-143]-> 5
        isValidTransition[19][i] <== CheckByteRangeTransition()(9, 5, 128, 143, currStates[i], nextStates[i], haystack[i]);

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

}
