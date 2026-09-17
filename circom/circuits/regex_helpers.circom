pragma circom 2.1.9;

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

template CheckByteTransitionWithCapture(numCaptureGroups) {
    signal input currState;
    signal input nextState;
    signal input byte;
    signal input captureGroupId[numCaptureGroups];
    signal input captureGroupStart[numCaptureGroups];

    signal input inCurrState;
    signal input inNextState;
    signal input inByte;
    signal input inCaptureGroupId[numCaptureGroups];
    signal input inCaptureGroupStart[numCaptureGroups];
    signal output out;  

    component isCaptureGroupEqual = MultiAND(numCaptureGroups);
    component isCaptureGroupStartEqual = MultiAND(numCaptureGroups);
    
    for (var i = 0; i < numCaptureGroups; i++) {
        isCaptureGroupEqual.in[i] <== IsEqual()([captureGroupId[i], inCaptureGroupId[i]]);
        isCaptureGroupStartEqual.in[i] <== IsEqual()([captureGroupStart[i], inCaptureGroupStart[i]]);
    }
    signal isValidTransition <== CheckByteTransition()(currState, nextState, byte, inCurrState, inNextState, inByte);
    
    out <== MultiAND(3)([isValidTransition, isCaptureGroupEqual.out, isCaptureGroupStartEqual.out]);
}

template CheckByteRangeTransitionWithCapture(numCaptureGroups) {
    signal input currState;
    signal input nextState;
    signal input byteStart;
    signal input byteEnd;   
    signal input captureGroupId[numCaptureGroups];
    signal input captureGroupStart[numCaptureGroups];

    signal input inCurrState;
    signal input inNextState;
    signal input inByte;    
    signal input inCaptureGroupId[numCaptureGroups];
    signal input inCaptureGroupStart[numCaptureGroups];

    signal output out;

    component isCaptureGroupEqual = MultiAND(numCaptureGroups);
    component isCaptureGroupStartEqual = MultiAND(numCaptureGroups);
    for (var i = 0; i < numCaptureGroups; i++) {
        isCaptureGroupEqual.in[i] <== IsEqual()([captureGroupId[i], inCaptureGroupId[i]]);
        isCaptureGroupStartEqual.in[i] <== IsEqual()([captureGroupStart[i], inCaptureGroupStart[i]]);
    }
    signal isValidTransition <== CheckByteRangeTransition()(currState, nextState, byteStart, byteEnd, inCurrState, inNextState, inByte);

    out <== MultiAND(3)([isValidTransition, isCaptureGroupEqual.out, isCaptureGroupStartEqual.out]);
}

/// @title CaptureSubstring
/// @notice Extracts a specific capture group from a regex-matched haystack into a fixed-length output array.
/// @notice Uses a two-sweep approach to build a boolean mask over the haystack:
///           1. Forward sweep (left→right): sets a flag once the capture start is found.
///           2. Backward sweep (right→left): sets a flag while capture content exists at or ahead.
///           3. The AND of both sweeps isolates exactly the captured byte range.
///         The masked bytes are then shifted to the beginning of the output via SelectRegexReveal.
/// @param maxBytes Maximum length of the haystack array
/// @param maxSubstringBytes Maximum length of the captured substring output
/// @param captureId The ID of the capture group to extract
/// @input startIndex The haystack index where the capture group begins
/// @input haystack[maxBytes] Raw byte values of the input string
/// @input captureIds[maxBytes] Per-byte capture group ID assigned by the regex circuit (0 = not captured)
/// @input captureStarts[maxBytes] Per-byte start marker: 1 = first byte of a capture group, 0 = continuation or not captured
/// @output substring[maxSubstringBytes] The extracted capture group bytes, shifted to start at index 0
template CaptureSubstring(maxBytes, maxSubstringBytes, captureId) {
    signal input startIndex;
    signal input haystack[maxBytes];
    signal input captureIds[maxBytes];
    signal input captureStarts[maxBytes];

    signal output substring[maxSubstringBytes];

    // Per-byte boolean: does this byte belong to our target capture group?
    signal isCapture[maxBytes];
    // Per-byte boolean: is this byte marked as the start of a capture group?
    signal isCaptureStart[maxBytes];

    // Forward sweep: cumulative OR — once the capture start is found, stays 1 for all subsequent positions
    signal isValidCaptureStart[maxBytes];
    // Temporary: 1 only at the exact position where our capture group starts
    signal isValidCaptureStartTemp[maxBytes];
    // Backward sweep: cumulative OR — 1 at any position where capture content exists at or after it
    signal isValidCaptureEnd[maxBytes];

    // AND of both sweeps — 1 only within the exact capture range
    signal captureMask[maxBytes];
    // Haystack bytes zeroed out everywhere except the capture range
    signal capture[maxBytes];

    // Mark which bytes belong to our target capture group
    for (var i = 0; i < maxBytes; i++) {
        isCapture[i] <== IsEqual()([captureIds[i], captureId]);
    }

    // Phase 1: Forward sweep (left → right)
    // Builds isValidCaptureStart[i] which answers:
    //   "At position i, have we already seen the start of our capture group?"
    // Once the start is found, the flag stays 1 for all subsequent positions.
    for (var i = 0; i < maxBytes; i++) {
        // Is this byte marked as the start of any capture group?
        isCaptureStart[i] <== IsEqual()([captureStarts[i], 1]);
        // Is this the start of *our* capture group? (belongs to our group AND is a start marker)
        isValidCaptureStartTemp[i] <== AND()(isCapture[i], isCaptureStart[i]);
        if (i == 0) {
            // Base case: no previous positions to inherit from
            isValidCaptureStart[i] <== isValidCaptureStartTemp[i];
        } else {
            // Cumulative OR: once any previous position set it to 1, it stays 1
            isValidCaptureStart[i] <== OR()(isValidCaptureStartTemp[i], isValidCaptureStart[i-1]);
        }
    }

    // Phase 2: Backward sweep (right → left)
    // Builds isValidCaptureEnd[i] which answers:
    //   "At position i, does any captured byte exist at or after this position?"
    // Scans from the end; once a byte of our group is found, the flag propagates left.
    for (var i = maxBytes - 1; i >= 0; i--) {
        if (i == maxBytes - 1) {
            // Base case: no positions to the right to inherit from
            isValidCaptureEnd[i] <== isCapture[i];
        } else {
            // Cumulative OR: propagates rightmost capture content leftward
            isValidCaptureEnd[i] <== OR()(isCapture[i], isValidCaptureEnd[i+1]);
        }
    }

    // Phase 3: Intersection of both sweeps
    // captureMask[i] = 1 only where BOTH conditions hold:
    //   - The capture start has been seen (at or before position i)
    //   - Capture continuation content exists (at or after position i)
    // This isolates exactly the byte range of our capture group.
    for (var i = 0; i < maxBytes; i++) {
        captureMask[i] <== AND()(isValidCaptureStart[i], isValidCaptureEnd[i]);
    }

    // Apply the mask: zero out all bytes outside the capture range
    for (var i = 0; i < maxBytes; i++) {
        capture[i] <== haystack[i] * captureMask[i];
    }

    // Shift the captured bytes to the beginning of the output array.
    // SelectRegexReveal also validates that:
    //   - The byte at startIndex is non-zero (valid capture exists)
    //   - All bytes before startIndex are zero (mask worked correctly)
    //   - All bytes after startIndex + maxSubstringBytes are zero
    substring <== SelectRegexReveal(maxBytes, maxSubstringBytes)(capture, startIndex);
}
