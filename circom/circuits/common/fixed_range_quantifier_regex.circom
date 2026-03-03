pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: [a-z]{3}[0-9]{2,4}[A-Z]{1,2}
template FixedRangeQuantifierRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal output isValid;

    var numStartStates = 2;
    var numAcceptStates = 2;
    var numTransitions = 12;
    var startStates[numStartStates] = [0, 1];
    var acceptStates[numAcceptStates] = [9, 10];

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

    component reachedAcceptState[maxMatchBytes];

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

        // Transition 0: 0 -[97-122]-> 2
        isValidTransition[0][i] <== CheckByteRangeTransition()(0, 2, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 1: 1 -[97-122]-> 2
        isValidTransition[1][i] <== CheckByteRangeTransition()(1, 2, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 2: 2 -[97-122]-> 3
        isValidTransition[2][i] <== CheckByteRangeTransition()(2, 3, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 3: 3 -[97-122]-> 4
        isValidTransition[3][i] <== CheckByteRangeTransition()(3, 4, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 4: 4 -[48-57]-> 5
        isValidTransition[4][i] <== CheckByteRangeTransition()(4, 5, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 5: 5 -[48-57]-> 6
        isValidTransition[5][i] <== CheckByteRangeTransition()(5, 6, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 6: 6 -[48-57]-> 7
        isValidTransition[6][i] <== CheckByteRangeTransition()(6, 7, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 7: 6 -[65-90]-> 9
        isValidTransition[7][i] <== CheckByteRangeTransition()(6, 9, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 8: 7 -[48-57]-> 8
        isValidTransition[8][i] <== CheckByteRangeTransition()(7, 8, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 9: 7 -[65-90]-> 9
        isValidTransition[9][i] <== CheckByteRangeTransition()(7, 9, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 10: 8 -[65-90]-> 9
        isValidTransition[10][i] <== CheckByteRangeTransition()(8, 9, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 11: 9 -[65-90]-> 10
        isValidTransition[11][i] <== CheckByteRangeTransition()(9, 10, 65, 90, currStates[i], nextStates[i], haystack[i]);

        // Combine all valid transitions for this byte
        isValidTraversal[i] = MultiOR(numTransitions);
        for (var j = 0; j < numTransitions; j++) {
            isValidTraversal[i].in[j] <== isValidTransition[j][i];
        }
        isValidTraversal[i].out === isWithinPathLength[i];

        // Check if any accept state has been reached at the last transition
        reachedLastTransition[i] <== IsEqual()([i, matchLength-1]);
        reachedAcceptState[i] = MultiOR(numAcceptStates);
        for (var j = 0; j < numAcceptStates; j++) {
            reachedAcceptState[i].in[j] <== IsEqual()([nextStates[i], acceptStates[j]]);
        }
        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i].out);
        if (i == 0) {
            isValidRegex[i] <== isValidRegexTemp[i];
        } else {
            isValidRegex[i] <== isValidRegexTemp[i] + isValidRegex[i-1];
        }
    }

    isValid <== isValidRegex[maxMatchBytes-1];

}
