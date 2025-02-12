#!/bin/bash
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
BACKEND_BINARY_PATH=$(which bb)

cd $SCRIPT_DIR  

noir-profiler gates \
        --artifact-path ./simple/target/simple_regex.json \
        --backend-path $BACKEND_BINARY_PATH \
        --output ./simple
mv ./simple/main::gates.svg ./simple/simple_flamegraph.svg
