pragma circom 2.2.2;

include "circomlib/circuits/comparators.circom";

template MultiOR(n) {
    signal input in[n];
    signal output out;

    signal sums[n];
    sums[0] <== in[0];
    for (var i = 1; i < n; i++) {
        sums[i] <== sums[i-1] + in[i];
    }

    component is_zero = IsZero();
    is_zero.in <== sums[n-1];
    out <== 1 - is_zero.out;
}

template CheckByteTransition() {
    signal input currState;
    signal input nextState;
    signal input byte;

    signal input inCurrState;
    signal input inNextState;
    signal input inByte;

    signal output out;

    signal isCurrentState <== IsEqual()([currState, inCurrState]);
    signal isNextState <== IsEqual()([nextState, inNextState]);
    signal isByteEqual <== IsEqual()([byte, inByte]);

    out <== MultiAND(3)([isCurrentState, isNextState, isByteEqual]);
}

template CheckByteRangeTransition() {
    signal input currState;
    signal input nextState;
    signal input byteStart;
    signal input byteEnd;

    signal input inCurrState;
    signal input inNextState;
    signal input inByte;

    signal output out;

    signal isCurrentState <== IsEqual()([currState, inCurrState]);
    signal isNextState <== IsEqual()([nextState, inNextState]);

    signal isByteValid[2];
    isByteValid[0] <== GreaterEqThan(8)([inByte, byteStart]);
    isByteValid[1] <== LessEqThan(8)([inByte, byteEnd]);

    out <== MultiAND(4)([isCurrentState, isNextState, isByteValid[0], isByteValid[1]]);
}

template CheckByteTransitionWithCapture() {
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

    signal isCaptureGroupEqual <== IsEqual()([captureGroupId, inCaptureGroupId]);
    signal isCaptureGroupStartEqual <== IsEqual()([captureGroupStart, inCaptureGroupStart]);
    signal isValidTransition <== CheckByteTransition()(currState, nextState, byte, inCurrState, inNextState, inByte);
    
    out <== MultiAND(3)([isValidTransition, isCaptureGroupEqual, isCaptureGroupStartEqual]);
}

template CheckByteRangeTransitionWithCapture() {
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

    signal isCaptureGroupEqual <== IsEqual()([captureGroupId, inCaptureGroupId]);
    signal isCaptureGroupStartEqual <== IsEqual()([captureGroupStart, inCaptureGroupStart]);    
    signal isValidTransition <== CheckByteRangeTransition()(currState, nextState, byteStart, byteEnd, inCurrState, inNextState, inByte);

    out <== MultiAND(3)([isValidTransition, isCaptureGroupEqual, isCaptureGroupStartEqual]);
}

template CaptureSubstring(maxBytes, maxSubstringBytes, captureId) {
    signal input startIndex;
    signal input haystack[maxBytes];
    signal input captureIds[maxBytes];
    signal input captureStarts[maxBytes];

    signal output substring[maxSubstringBytes];

    signal isCapture[maxBytes];
    signal isCaptureStart[maxBytes];
    signal isCaptureEnd[maxBytes];

    signal isValidCaptureStart[maxBytes];
    signal isValidCaptureStartTemp[maxBytes];
    signal isValidCaptureEnd[maxBytes];
    signal isValidCaptureEndTemp[maxBytes];

    signal captureMask[maxBytes];
    signal capture[maxBytes];

    for (var i = 0; i < maxBytes; i++) {
        isCapture[i] <== IsEqual()([captureIds[i], captureId]);
    }

    for (var i = 0; i < maxBytes; i++) {
        isCaptureStart[i] <== IsEqual()([captureStarts[i], 1]);
        isValidCaptureStartTemp[i] <== AND()(isCapture[i], isCaptureStart[i]);
        if (i == 0) {
            isValidCaptureStart[i] <== isValidCaptureStartTemp[i];
        } else {
            isValidCaptureStart[i] <== OR()(isValidCaptureStartTemp[i], isValidCaptureStart[i-1]);
        }
    }

    for (var i = maxBytes - 1; i >= 0; i--) {
        isCaptureEnd[i] <== IsEqual()([captureStarts[i], 0]);
        isValidCaptureEndTemp[i] <== AND()(isCapture[i], isCaptureEnd[i]);
        if (i == maxBytes - 1) {
            isValidCaptureEnd[i] <== isValidCaptureEndTemp[i];
        } else {
            isValidCaptureEnd[i] <== OR()(isValidCaptureEndTemp[i], isValidCaptureEnd[i+1]);
        }
    }

    for (var i = 0; i < maxBytes; i++) {
        captureMask[i] <== AND()(isValidCaptureStart[i], isValidCaptureEnd[i]);
    }

    for (var i = 0; i < maxBytes; i++) {
        capture[i] <== haystack[i] * captureMask[i];
    }

    substring <== SelectRegexReveal(maxBytes, maxSubstringBytes)(capture, startIndex);
}
