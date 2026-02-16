pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: [A-Za-z0-9_]+
template QuantifiedAlphanumericRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal output isValid;

    var numStartStates = 2;
    var numAcceptStates = 1;
    var numTransitions = 12;
    var startStates[numStartStates] = [0, 1];
    var acceptStates[numAcceptStates] = [2];

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

        // Transition 0: 0 -[48-57]-> 2
        isValidTransition[0][i] <== CheckByteRangeTransition()(0, 2, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 1: 0 -[65-90]-> 2
        isValidTransition[1][i] <== CheckByteRangeTransition()(0, 2, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 2: 0 -[95]-> 2
        isValidTransition[2][i] <== CheckByteTransition()(0, 2, 95, currStates[i], nextStates[i], haystack[i]);
        // Transition 3: 0 -[97-122]-> 2
        isValidTransition[3][i] <== CheckByteRangeTransition()(0, 2, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 4: 1 -[48-57]-> 2
        isValidTransition[4][i] <== CheckByteRangeTransition()(1, 2, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 5: 1 -[65-90]-> 2
        isValidTransition[5][i] <== CheckByteRangeTransition()(1, 2, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 6: 1 -[95]-> 2
        isValidTransition[6][i] <== CheckByteTransition()(1, 2, 95, currStates[i], nextStates[i], haystack[i]);
        // Transition 7: 1 -[97-122]-> 2
        isValidTransition[7][i] <== CheckByteRangeTransition()(1, 2, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 8: 2 -[48-57]-> 2
        isValidTransition[8][i] <== CheckByteRangeTransition()(2, 2, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 9: 2 -[65-90]-> 2
        isValidTransition[9][i] <== CheckByteRangeTransition()(2, 2, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 10: 2 -[95]-> 2
        isValidTransition[10][i] <== CheckByteTransition()(2, 2, 95, currStates[i], nextStates[i], haystack[i]);
        // Transition 11: 2 -[97-122]-> 2
        isValidTransition[11][i] <== CheckByteRangeTransition()(2, 2, 97, 122, currStates[i], nextStates[i], haystack[i]);

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
