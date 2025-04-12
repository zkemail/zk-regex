#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../../.."

echo "Generating regex circuit for timestamp"
cargo run \
    --bin zk-regex decomposed \
    --decomposed-regex-path ./noir/timestamp/templates/timestamp.json \
    --output-file-path ./noir/timestamp/templates \
    --template-name Timestamp \
    --noir

mv ./noir/timestamp/templates/timestamp_regex.nr ./noir/timestamp/src/regex.nr

cd ./noir/timestamp

echo "Compiling executable"
nargo compile --silence-warnings
echo "Complete"
