pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";
include "@zk-email/circuits/utils/array.circom";

// regex: a*b
template SimpleRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal input traversalPathLength;

    signal output isValid;

    var numStartStates = 3;
    var numAcceptStates = 1;
    var numTransitions = 6;
    var startStates[numStartStates] = [0, 2, 3];
    var acceptStates[numAcceptStates] = [4];

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

        // Transition 0: 0 -[97]-> 1
        isValidTransition[0][i] <== CheckByteTransition()(0, 1, 97, currStates[i], nextStates[i], haystack[i]);
        // Transition 1: 1 -[97]-> 1
        isValidTransition[1][i] <== CheckByteTransition()(1, 1, 97, currStates[i], nextStates[i], haystack[i]);
        // Transition 2: 0 -[98]-> 4
        isValidTransition[2][i] <== CheckByteTransition()(0, 4, 98, currStates[i], nextStates[i], haystack[i]);
        // Transition 3: 1 -[98]-> 4
        isValidTransition[3][i] <== CheckByteTransition()(1, 4, 98, currStates[i], nextStates[i], haystack[i]);
        // Transition 4: 2 -[97]-> 1
        isValidTransition[4][i] <== CheckByteTransition()(2, 1, 97, currStates[i], nextStates[i], haystack[i]);
        // Transition 5: 3 -[98]-> 4
        isValidTransition[5][i] <== CheckByteTransition()(3, 4, 98, currStates[i], nextStates[i], haystack[i]);

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

}
