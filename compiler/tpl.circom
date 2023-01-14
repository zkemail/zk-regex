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

    signal output reveal[num_bytes];
    for (var i = 0; i < num_bytes; i++) {
        reveal[i] <== in[i] * states[i+1][1];
    }

    signal output matches[num_bytes][3];

    component check_cur[num_bytes];
    component check_start[num_bytes];
    signal states_count[num_bytes];
    var count = 0;

    //counting the matches by deterining the start positions of the matches
    check_cur[0] = IsEqual();
    check_cur[0].in[0] <== 0;
    check_cur[0].in[1] <== 1;
    
    for (var i = 1; i < num_bytes; i++) {
        check_cur[i] = IsEqual();
        check_cur[i].in[0] <== states[i][1];
        check_cur[i].in[1] <== 1;

        check_start[i] = AND();
        check_start[i].a <== check_cur[i].out;
        check_start[i].b <== 1 - check_cur[i-1].out;
        count += check_start[i].out;

        states_count[i] <== states[i][1] * count;
    }

    out <== count;
}
