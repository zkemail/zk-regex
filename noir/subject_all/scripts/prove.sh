#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../../.."

HAYSTACK=$(echo -e "\r\nsubject: this si a buject\r\n ")

echo "Generating input using haystack: $HAYSTACK"

cargo run \
    --bin zk-regex generate-circuit-input \
    --graph-path ./noir/subject_all/templates/subject_all_graph.json \
    --input "$HAYSTACK" \
    --max-haystack-len 50 \
    --max-match-len 50 \
    --output ./noir/subject_all/Prover.toml \
    --noir true

echo "Simulating witness for subject_all regex match"
cd ./noir/subject_all
nargo execute

