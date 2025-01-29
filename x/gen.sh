#!/bin/bash

GEN_SUBSTRINGS=true

# generate using sparse array
zk-regex decomposed -d x.json \
    --noir-file-path ./sparse/src/regex.nr \
    -g $GEN_SUBSTRINGS \
    --sparse-array true

# generate using simple array
zk-regex decomposed -d x.json \
    --noir-file-path ./simple/src/regex.nr \
    -g $GEN_SUBSTRINGS \
    --sparse-array false