pragma circom 2.1.5;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";
include "@zk-email/circuits/utils/regex.circom";
include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: (?:https?|ftp)://(?:www\\.)?[a-z0-9.-]+\\.[a-z]{2,}
template ComplexAlternationGroupsRegex(maxHaystackBytes, maxMatchBytes) {
    signal input inHaystack[maxHaystackBytes];
    signal input matchStart;
    signal input matchLength;

    signal input currStates[maxMatchBytes];
    signal input nextStates[maxMatchBytes];
    signal output isValid;

    var numStartStates = 3;
    var numAcceptStates = 1;
    var numTransitions = 31;
    var startStates[numStartStates] = [0, 1, 6];
    var acceptStates[numAcceptStates] = [20];

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

        // Transition 0: 0 -[104]-> 2
        isValidTransition[0][i] <== CheckByteTransition()(0, 2, 104, currStates[i], nextStates[i], haystack[i]);
        // Transition 1: 0 -[102]-> 7
        isValidTransition[1][i] <== CheckByteTransition()(0, 7, 102, currStates[i], nextStates[i], haystack[i]);
        // Transition 2: 1 -[104]-> 2
        isValidTransition[2][i] <== CheckByteTransition()(1, 2, 104, currStates[i], nextStates[i], haystack[i]);
        // Transition 3: 2 -[116]-> 3
        isValidTransition[3][i] <== CheckByteTransition()(2, 3, 116, currStates[i], nextStates[i], haystack[i]);
        // Transition 4: 3 -[116]-> 4
        isValidTransition[4][i] <== CheckByteTransition()(3, 4, 116, currStates[i], nextStates[i], haystack[i]);
        // Transition 5: 4 -[112]-> 5
        isValidTransition[5][i] <== CheckByteTransition()(4, 5, 112, currStates[i], nextStates[i], haystack[i]);
        // Transition 6: 5 -[115]-> 9
        isValidTransition[6][i] <== CheckByteTransition()(5, 9, 115, currStates[i], nextStates[i], haystack[i]);
        // Transition 7: 5 -[58]-> 10
        isValidTransition[7][i] <== CheckByteTransition()(5, 10, 58, currStates[i], nextStates[i], haystack[i]);
        // Transition 8: 6 -[102]-> 7
        isValidTransition[8][i] <== CheckByteTransition()(6, 7, 102, currStates[i], nextStates[i], haystack[i]);
        // Transition 9: 7 -[116]-> 8
        isValidTransition[9][i] <== CheckByteTransition()(7, 8, 116, currStates[i], nextStates[i], haystack[i]);
        // Transition 10: 8 -[112]-> 9
        isValidTransition[10][i] <== CheckByteTransition()(8, 9, 112, currStates[i], nextStates[i], haystack[i]);
        // Transition 11: 9 -[58]-> 10
        isValidTransition[11][i] <== CheckByteTransition()(9, 10, 58, currStates[i], nextStates[i], haystack[i]);
        // Transition 12: 10 -[47]-> 11
        isValidTransition[12][i] <== CheckByteTransition()(10, 11, 47, currStates[i], nextStates[i], haystack[i]);
        // Transition 13: 11 -[47]-> 12
        isValidTransition[13][i] <== CheckByteTransition()(11, 12, 47, currStates[i], nextStates[i], haystack[i]);
        // Transition 14: 12 -[119]-> 13
        isValidTransition[14][i] <== CheckByteTransition()(12, 13, 119, currStates[i], nextStates[i], haystack[i]);
        // Transition 15: 12 -[45-46]-> 17
        isValidTransition[15][i] <== CheckByteRangeTransition()(12, 17, 45, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 16: 12 -[48-57]-> 17
        isValidTransition[16][i] <== CheckByteRangeTransition()(12, 17, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 17: 12 -[97-122]-> 17
        isValidTransition[17][i] <== CheckByteRangeTransition()(12, 17, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 18: 13 -[119]-> 14
        isValidTransition[18][i] <== CheckByteTransition()(13, 14, 119, currStates[i], nextStates[i], haystack[i]);
        // Transition 19: 14 -[119]-> 15
        isValidTransition[19][i] <== CheckByteTransition()(14, 15, 119, currStates[i], nextStates[i], haystack[i]);
        // Transition 20: 15 -[46]-> 16
        isValidTransition[20][i] <== CheckByteTransition()(15, 16, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 21: 16 -[45-46]-> 17
        isValidTransition[21][i] <== CheckByteRangeTransition()(16, 17, 45, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 22: 16 -[48-57]-> 17
        isValidTransition[22][i] <== CheckByteRangeTransition()(16, 17, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 23: 16 -[97-122]-> 17
        isValidTransition[23][i] <== CheckByteRangeTransition()(16, 17, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 24: 17 -[45-46]-> 17
        isValidTransition[24][i] <== CheckByteRangeTransition()(17, 17, 45, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 25: 17 -[48-57]-> 17
        isValidTransition[25][i] <== CheckByteRangeTransition()(17, 17, 48, 57, currStates[i], nextStates[i], haystack[i]);
        // Transition 26: 17 -[97-122]-> 17
        isValidTransition[26][i] <== CheckByteRangeTransition()(17, 17, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 27: 17 -[46]-> 18
        isValidTransition[27][i] <== CheckByteTransition()(17, 18, 46, currStates[i], nextStates[i], haystack[i]);
        // Transition 28: 18 -[97-122]-> 19
        isValidTransition[28][i] <== CheckByteRangeTransition()(18, 19, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 29: 19 -[97-122]-> 20
        isValidTransition[29][i] <== CheckByteRangeTransition()(19, 20, 97, 122, currStates[i], nextStates[i], haystack[i]);
        // Transition 30: 20 -[97-122]-> 20
        isValidTransition[30][i] <== CheckByteRangeTransition()(20, 20, 97, 122, currStates[i], nextStates[i], haystack[i]);

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
