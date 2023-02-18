pragma circom 2.0.3;

include "CIRCUIT_FOLDER/regex_helpers.circom";

template TEMPLATE_NAME_PLACEHOLDER (msg_bytes, reveal_bytes) {
    signal input msg[msg_bytes];
    signal input match_idx;
    signal output start_idx;
    signal output out;

    signal reveal_shifted_intermediate[reveal_bytes][msg_bytes];
    signal output reveal_shifted[reveal_bytes];

    var num_bytes = msg_bytes;
    signal in[num_bytes];
    for (var i = 0; i < msg_bytes; i++) {
        in[i] <== msg[i];
    }

    COMPILED_CONTENT_PLACEHOLDER

    // a flag to indicate the start position of the match
    var start_index = 0;
    // for counting the number of matches
    var count = 0;

    // lengths to be consistent with states signal
    component check_start[num_bytes + 1];
    component check_match[num_bytes + 1];
    component check_matched_start[num_bytes + 1];
    component matched_idx_eq[msg_bytes];

    for (var i = 0; i < num_bytes; i++) {
        if (i == 0) {
            count += states[1][1];
        }
        else {
            check_start[i] = AND();
            check_start[i].a <== states[i + 1][1];
            check_start[i].b <== 1 - states[i][1];

            count += check_start[i].out;

            check_match[i] = IsEqual();
            check_match[i].in[0] <== count;
            check_match[i].in[1] <== match_idx;

            check_matched_start[i] = AND();
            check_matched_start[i].a <== check_match[i].out;
            check_matched_start[i].b <== check_start[i].out;
            start_index += check_matched_start[i].out * i;
        }

        matched_idx_eq[i] = IsEqual();
        matched_idx_eq[i].in[0] <== states[i + 1][1] * count;
        matched_idx_eq[i].in[1] <== match_idx;
    }

    component match_start_idx[msg_bytes];
    for (var i = 0; i < msg_bytes; i++) {
        match_start_idx[i] = IsEqual();
        match_start_idx[i].in[0] <== i;
        match_start_idx[i].in[1] <== start_index;
    }

    signal reveal_match[msg_bytes];
    for (var i = 0; i < msg_bytes; i++) {
        reveal_match[i] <== matched_idx_eq[i].out * reveal[i];
    }

    for (var j = 0; j < reveal_bytes; j++) {
        reveal_shifted_intermediate[j][j] <== 0;
        for (var i = j + 1; i < msg_bytes; i++) {
            // This shifts matched string back to the beginning. 
            reveal_shifted_intermediate[j][i] <== reveal_shifted_intermediate[j][i - 1] + match_start_idx[i-j].out * reveal_match[i];
        }
        reveal_shifted[j] <== reveal_shifted_intermediate[j][msg_bytes - 1];
    }

    out <== count;
    start_idx <== start_index;
}
