pragma circom 2.1.5;

template CheckByteTransition() {
    signal input currState;
    signal input nextState;
    signal input byte;
    signal input captureGroupId;
    signal input captureGroupStart;

    signal input inCurrState;
    signal input inNextState;
    signal input inByte;
    signal input inCaptureGroupId;
    signal input inCaptureGroupStart;

    signal output out;

    signal isCurrentState <== IsEqual()([currState, inCurrState]);
    signal isNextState <== IsEqual()([nextState, inNextState]);
    signal isByteEqual <== IsEqual()([byte, inByte]);
    signal isCaptureGroupEqual <== IsEqual()([captureGroupId, inCaptureGroupId]);
    signal isCaptureGroupStartEqual <== IsEqual()([captureGroupStart, inCaptureGroupStart]);

    out <== MultiAND(5)([isCurrentState, isNextState, isByteEqual, isCaptureGroupEqual, isCaptureGroupStartEqual]);
}

template CheckByteRangeTransition() {
    signal input currState;
    signal input nextState;
    signal input byteStart;
    signal input byteEnd;
    signal input captureGroupId;
    signal input captureGroupStart;

    signal input inCurrState;
    signal input inNextState;
    signal input inByte;
    signal input inCaptureGroupId;
    signal input inCaptureGroupStart;

    signal output out;

    signal isCurrentState <== IsEqual()([currState, inCurrState]);
    signal isNextState <== IsEqual()([nextState, inNextState]);
    signal isCaptureGroupEqual <== IsEqual()([captureGroupId, inCaptureGroupId]);
    signal isCaptureGroupStartEqual <== IsEqual()([captureGroupStart, inCaptureGroupStart]);

    signal isByteValid[2];
    isByteValid[0] <== GreaterEqThan(8)([inByte, byteStart]);
    isByteValid[1] <== LessEqThan(8)([inByte, byteEnd]);

    out <== MultiAND(5)([isCurrentState, isNextState, isByteValid[0], isByteValid[1], isCaptureGroupEqual, isCaptureGroupStartEqual]);
}

template Regex(maxBytes) { 
    signal input currStates[maxBytes];
    signal input haystack[maxBytes];
    signal input nextStates[maxBytes];
    signal input captureGroupIds[maxBytes];
    signal input captureGroupStarts[maxBytes];
    signal input traversalPathLength;

    var numStartStates = 6;
    var numAcceptStates = 1;
    var numTransitions = 10;
    var startStates[numStartStates] = [4, 3, 2, 0, 5, 1];
    var acceptStates[numAcceptStates] = [6];

    signal isCurrentState[numTransitions][maxBytes];
    signal isNextState[numTransitions][maxBytes];
    signal isValidTransition[numTransitions][maxBytes];
    signal reachedLastTransition[maxBytes];
    signal reachedAcceptState[maxBytes];
    signal isValidRegex[maxBytes];
    signal isValidRegexTemp[maxBytes];
    signal isWithinPathLength[maxBytes];
    signal isTransitionLinked[maxBytes];
    
    component isValidStartState;
    component isValidTraversal[maxBytes];

    // Check if the first state in the haystack is a valid start state
    isValidStartState = MultiOR(numStartStates);
    for (var i = 0; i < numStartStates; i++) {
        isValidStartState.in[i] <== IsEqual()([startStates[i], currStates[0]]);
    }
    isValidStartState.out === 1;

    // Check if the traversal path has valid transitions
    for (var i = 0; i < maxBytes; i++) {
        isWithinPathLength[i] <== LessThan(log2Ceil(maxBytes))([i, traversalPathLength]);

        // Check if the traversal is a valid path
        if (i !== maxBytes - 1) {
            isTransitionLinked[i] <== IsEqual()([nextStates[i], currStates[i+1]]);
            isTransitionLinked[i] === isWithinPathLength[i];
        }

        // Transition 0: 0 -[0-255]-> 0
        isValidTransition[0][i] <== CheckByteRangeTransition()(0, 0, 0, 255, currStates[i], nextStates[i], haystack[i]);

        // Transition 1: 0 -[97-97]-> 3
        isValidTransition[1][i] <== CheckByteTransition()(0, 3, 97, 1, 1, currStates[i], nextStates[i], haystack[i]);

        // Transition 2: 0 -[98-98]-> 6
        isValidTransition[2][i] <== CheckByteTransition()(0, 6, 98, currStates[i], nextStates[i], haystack[i])

        // Transition 3: 1 -[0-255]-> 0
        isValidTransition[3][i] <== CheckByteRangeTransition()(1, 0, 0, 255, currStates[i], nextStates[i], haystack[i]);

        // Transition 4: 2 -[98-98]-> 6
        isValidTransition[4][i] <== CheckByteTransition()(2, 6, 98, currStates[i], nextStates[i], haystack[i]);

        // Transition 5: 2 -[97-97]-> 3
        isValidTransition[5][i] <== CheckByteTransition()(2, 3, 97, currStates[i], nextStates[i], haystack[i]);
        
        // Transition 6: 3 -[98-98]-> 6
        isValidTransition[6][i] <== CheckByteTransition()(3, 6, 98, currStates[i], nextStates[i], haystack[i]);

        // Transition 7: 3 -[97-97]-> 3
        isValidTransition[7][i] <== CheckByteTransition()(3, 3, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 8: 4 -[97-97]-> 3
        isValidTransition[8][i] <== CheckByteTransition()(4, 3, 97, currStates[i], nextStates[i], haystack[i]);

        // Transition 9: 5 -[98-98]-> 6
        isValidTransition[9][i] <== CheckByteTransition()(5, 6, 98, currStates[i], nextStates[i], haystack[i]);

        // Combine all valid transitions for this byte
        isValidTraversal[i] = MultiOR(numTransitions);
        for (var j = 0; j < numTransitions; j++) {
            isValidTraversal[i].in[j] <== isValidTransition[j][i];
        }
        isValidTraversal[i].out === isWithinPathLength[i];

        // Check if any accept state has been reached at the last transition
        reachedLastTransition[i] <== IsEqual()([i, traversalPathLength]);
        reachedAcceptState[i] <== IsEqual()([nextStates[i], acceptStates[0]]);
        isValidRegexTemp[i] <== AND()(reachedLastTransition[i], reachedAcceptState[i]);
        if (i == 0) {
            isValidRegex[i] <== isValidRegexTemp[i];
        } else {
            isValidRegex[i] <== isValidRegexTemp[i] + isValidRegex[i-1];
        }
    }
    isValidRegex[maxBytes-1] === 1;

    // Capture group 1
    signal isCaptureGroup1[maxBytes];
    signal isCaptureGroupStart1[maxBytes];
    signal isCaptureGroupEnd1[maxBytes];
    signal isValidCaptureStart1[maxBytes];
    signal isValidCaptureEnd1[maxBytes];
    for (var i = 0; i < maxBytes; i++) {
        isCaptureGroup1[i] <== IsEqual()([captureGroupIds[i], 1]);
        isCaptureGroupStart1[i] <== IsEqual()([captureGroupStarts[i], 1]);
        isCaptureGroupEnd1[i] <== IsEqual()([captureGroupStarts[i], 0]);
        if (i == 0) {
            isValidCaptureStart1[i] <== AND()(isCaptureGroup1[i], isCaptureGroupStart1[i]);
            isValidCaptureEnd1[i] <== AND()(isCaptureGroup1[i], isCaptureGroupEnd1[i]);
        } else {
            isValidCaptureStart1[i] <== AND()(isCaptureGroup1[i], isCaptureGroupStart1[i]) + isValidCaptureStart1[i-1];
            isValidCaptureEnd1[i] <== AND()(isCaptureGroup1[i], isCaptureGroupEnd1[i]) + isValidCaptureEnd1[i-1];
        }
    }
}