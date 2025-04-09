#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../../.."

# cargo run \
#     --bin zk-regex decomposed \
#     --decomposed-regex-path ./noir/templates/timestamp.json \
#     --output-file-path ./noir/templates/ \
#     --template-name Timestamp

echo "Generating regex circuit for subject_all"
cargo run \
    --bin zk-regex decomposed \
    --decomposed-regex-path ./noir/subject_all/templates/subject_all.json \
    --output-file-path ./noir/subject_all/templates \
    --template-name SubjectAll \
    --noir

mv ./noir/subject_all/templates/subject_all_regex.nr ./noir/subject_all/src/regex.nr

cd ./noir/subject_all

echo "Compiling executable"
nargo compile --silence-warnings
echo "Complete"
