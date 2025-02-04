#!/bin/bash

GEN_SUBSTRINGS=true

# generate using sparse array
zk-regex raw \
    -r "1=(a|b) (2=(b|c)+ )+d" \
    -s ./transitions.json \
    --noir-file-path ./sparse/src/regex.nr \
    -g $GEN_SUBSTRINGS \
    --sparse-array true

# generate using simple array
zk-regex raw \
    -r "1=(a|b) (2=(b|c)+ )+d" \
    -s ./transitions.json \
    --noir-file-path ./simple/src/regex.nr \
    -g $GEN_SUBSTRINGS \
    --sparse-array false