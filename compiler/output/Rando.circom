pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/regex_helpers.circom";

// regex: a*b
template RandoRegex(maxBytes) {
signal input currStates[maxBytes];
signal input haystack[maxBytes];
signal input nextStates[maxBytes];
signal input traversalPathLength;

var numStartStates = 4;
var numAcceptStates = 2;
var numTransitions = 11;
var startStates[numStartStates] = [0, 2, 3, 1];
var acceptStates[numAcceptStates] = [4, 5];

signal isCurrentState[numTransitions][maxBytes];
signal isNextState[numTransitions][maxBytes];
signal isValidTransition[numTransitions][maxBytes];
signal reachedLastTransition[maxBytes];
signal reachedAcceptState[maxBytes];
signal isValidRegex[maxBytes];
signal isValidRegexTemp[maxBytes];
signal isWithinPathLength[maxBytes];
signal isTransitionLinked[maxBytes];

component isValidTraversal[maxBytes];

    // Check if the first state in the haystack is a valid start state
    component isValidStartState;
    isValidStartState = MultiOR(numStartStates);
    for (var i = 0; i < numStartStates; i++) {
        isValidStartState.in[i] <== IsEqual()([startStates[i], currStates[0]]);
    }
    isValidStartState.out === 1;

    // Check if the traversal path has valid transitions
    for (var i = 0; i < maxBytes; i++) {
        isWithinPathLength[i] <== LessThan(log2Ceil(maxBytes))([i, traversalPathLength]);

        // Check if the traversal is a valid path
        if (i != maxBytes - 1) {
            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);
            isTransitionLinked[i] === isWithinPathLength[i];
        }

        // Transition 0: 0 -[0-255]-> 0
isValidTransition[0][i] <== CheckByteRangeTransition()(0, 0, 0, 255, currStates[i], nextStates[i], haystack[i]);

        // Transition 1: 0 -[97]-> 4
isValidTransition[1][i] <== CheckByteTransition()(0, 4, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 2: 1 -[0-255]-> 0
isValidTransition[2][i] <== CheckByteRangeTransition()(1, 0, 0, 255, currStates[i], nextStates[i], haystack[i]);

        // Transition 3: 2 -[97]-> 4
isValidTransition[3][i] <== CheckByteTransition()(2, 4, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 4: 3 -[97]-> 4
isValidTransition[4][i] <== CheckByteTransition()(3, 4, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 5: 4 -[97]-> 5
isValidTransition[5][i] <== CheckByteTransition()(4, 5, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 6: 4 -[97]-> 5
isValidTransition[6][i] <== CheckByteTransition()(4, 5, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 7: 4 -[97]-> 5
isValidTransition[7][i] <== CheckByteTransition()(4, 5, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 8: 5 -[97]-> 5
isValidTransition[8][i] <== CheckByteTransition()(5, 5, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 9: 5 -[97]-> 5
isValidTransition[9][i] <== CheckByteTransition()(5, 5, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 10: 6 -[97]-> 5
isValidTransition[10][i] <== CheckByteTransition()(6, 5, 97, currStates[i], nextStates[i], haystack[i]);

        // Combine all valid transitions for this byte
        isValidTraversal[i] = MultiOR(numTransitions);
        for (var j = 0; j < numTransitions; j++) {
            isValidTraversal[i].in[j] <== isValidTransition[j][i];
        }
        isValidTraversal[i].out === isWithinPathLength[i];

        // Check if any accept state has been reached at the last transition
        reachedLastTransition[i] <== IsEqual()([i, traversalPathLength]);
        component isAcceptState = MultiOR(numAcceptStates);
        for (var j = 0; j < numAcceptStates; j++) {
            isAcceptState.in[j] <== IsEqual()([acceptStates[j], nextStates[i]]);
        }
        reachedAcceptState[i] <== isAcceptState.out;
        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i]);
        if (i == 0) {
            isValidRegex[i] <== isValidRegexTemp[i];
        } else {
            isValidRegex[i] <== isValidRegexTemp[i] + isValidRegex[i-1];
        }
    }

    isValidRegex[maxBytes-1] === 1;
}
