pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}
template EmailBasicRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal output isValid;

    var numStartStates = 2;
    var numAcceptStates = 1;
    var numTransitions = 37;
    var startStates[numStartStates] = [0, 1];
    var acceptStates[numAcceptStates] = [7];

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

        // Transition 0: 0 -[37]-> 2
        isValidTransition[0][i] <== CheckByteTransition()(0, 2, 37, currStates[i], nextStates[i], haystack[i]);
        // Transition 1: 0 -[43]-> 2
        isValidTransition[1][i] <== CheckByteTransition()(0, 2, 43, currStates[i], nextStates[i], haystack[i]);
        // Transition 2: 0 -[45-46]-> 2
        isValidTransition[2][i] <== CheckByteRangeTransition()(0, 2, 45, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 3: 0 -[48-57]-> 2
        isValidTransition[3][i] <== CheckByteRangeTransition()(0, 2, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 4: 0 -[65-90]-> 2
        isValidTransition[4][i] <== CheckByteRangeTransition()(0, 2, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 5: 0 -[95]-> 2
        isValidTransition[5][i] <== CheckByteTransition()(0, 2, 95, currStates[i], nextStates[i], haystack[i]);
        // Transition 6: 0 -[97-122]-> 2
        isValidTransition[6][i] <== CheckByteRangeTransition()(0, 2, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 7: 1 -[37]-> 2
        isValidTransition[7][i] <== CheckByteTransition()(1, 2, 37, currStates[i], nextStates[i], haystack[i]);
        // Transition 8: 1 -[43]-> 2
        isValidTransition[8][i] <== CheckByteTransition()(1, 2, 43, currStates[i], nextStates[i], haystack[i]);
        // Transition 9: 1 -[45-46]-> 2
        isValidTransition[9][i] <== CheckByteRangeTransition()(1, 2, 45, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 10: 1 -[48-57]-> 2
        isValidTransition[10][i] <== CheckByteRangeTransition()(1, 2, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 11: 1 -[65-90]-> 2
        isValidTransition[11][i] <== CheckByteRangeTransition()(1, 2, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 12: 1 -[95]-> 2
        isValidTransition[12][i] <== CheckByteTransition()(1, 2, 95, currStates[i], nextStates[i], haystack[i]);
        // Transition 13: 1 -[97-122]-> 2
        isValidTransition[13][i] <== CheckByteRangeTransition()(1, 2, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 14: 2 -[37]-> 2
        isValidTransition[14][i] <== CheckByteTransition()(2, 2, 37, currStates[i], nextStates[i], haystack[i]);
        // Transition 15: 2 -[43]-> 2
        isValidTransition[15][i] <== CheckByteTransition()(2, 2, 43, currStates[i], nextStates[i], haystack[i]);
        // Transition 16: 2 -[45-46]-> 2
        isValidTransition[16][i] <== CheckByteRangeTransition()(2, 2, 45, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 17: 2 -[48-57]-> 2
        isValidTransition[17][i] <== CheckByteRangeTransition()(2, 2, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 18: 2 -[65-90]-> 2
        isValidTransition[18][i] <== CheckByteRangeTransition()(2, 2, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 19: 2 -[95]-> 2
        isValidTransition[19][i] <== CheckByteTransition()(2, 2, 95, currStates[i], nextStates[i], haystack[i]);
        // Transition 20: 2 -[97-122]-> 2
        isValidTransition[20][i] <== CheckByteRangeTransition()(2, 2, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 21: 2 -[64]-> 3
        isValidTransition[21][i] <== CheckByteTransition()(2, 3, 64, currStates[i], nextStates[i], haystack[i]);
        // Transition 22: 3 -[45-46]-> 4
        isValidTransition[22][i] <== CheckByteRangeTransition()(3, 4, 45, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 23: 3 -[48-57]-> 4
        isValidTransition[23][i] <== CheckByteRangeTransition()(3, 4, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 24: 3 -[65-90]-> 4
        isValidTransition[24][i] <== CheckByteRangeTransition()(3, 4, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 25: 3 -[97-122]-> 4
        isValidTransition[25][i] <== CheckByteRangeTransition()(3, 4, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 26: 4 -[45-46]-> 4
        isValidTransition[26][i] <== CheckByteRangeTransition()(4, 4, 45, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 27: 4 -[48-57]-> 4
        isValidTransition[27][i] <== CheckByteRangeTransition()(4, 4, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 28: 4 -[65-90]-> 4
        isValidTransition[28][i] <== CheckByteRangeTransition()(4, 4, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 29: 4 -[97-122]-> 4
        isValidTransition[29][i] <== CheckByteRangeTransition()(4, 4, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 30: 4 -[46]-> 5
        isValidTransition[30][i] <== CheckByteTransition()(4, 5, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 31: 5 -[65-90]-> 6
        isValidTransition[31][i] <== CheckByteRangeTransition()(5, 6, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 32: 5 -[97-122]-> 6
        isValidTransition[32][i] <== CheckByteRangeTransition()(5, 6, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 33: 6 -[65-90]-> 7
        isValidTransition[33][i] <== CheckByteRangeTransition()(6, 7, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 34: 6 -[97-122]-> 7
        isValidTransition[34][i] <== CheckByteRangeTransition()(6, 7, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 35: 7 -[65-90]-> 7
        isValidTransition[35][i] <== CheckByteRangeTransition()(7, 7, 65, 90, currStates[i], nextStates[i], haystack[i]);
        // Transition 36: 7 -[97-122]-> 7
        isValidTransition[36][i] <== CheckByteRangeTransition()(7, 7, 97, 122, currStates[i], nextStates[i], haystack[i]);

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
