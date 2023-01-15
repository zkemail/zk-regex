pragma circom 2.0.3;

include "CIRCUIT_FOLDER/regex_helpers.circom";

template TEMPLATE_NAME_PLACEHOLDER (msg_bytes) {
    signal input msg[msg_bytes];
    signal output out;

    var num_bytes = msg_bytes;
    signal in[num_bytes];
    for (var i = 0; i < msg_bytes; i++) {
        in[i] <== msg[i];
    }

    COMPILED_CONTENT_PLACEHOLDER

    // lengths to be consistent with states signal
    component check_cur[num_bytes + 1];
    component check_start[num_bytes + 1];
    signal states_count[num_bytes + 1];
    var count = 0;

    // counting the matches by deterining the start positions of the matches
    // note that the valid index of states signal starts from 1
    for (var i = 0; i < num_bytes; i++) {
        if (i == 0) {
            check_cur[i] = IsEqual();
            check_cur[i].in[0] <== states[1][1];
            check_cur[i].in[1] <== 1;

            count += states[1][1];
        }
        else {
            check_cur[i] = IsEqual();
            check_cur[i].in[0] <== states[i + 1][1];
            check_cur[i].in[1] <== 1;

            check_start[i] = AND();
            check_start[i].a <== check_cur[i].out;
            check_start[i].b <== 1 - check_cur[i-1].out;

            count += check_start[i].out;
        }
        states_count[i] <== states[i + 1][1] * count;
    }

    out <== count;
}
