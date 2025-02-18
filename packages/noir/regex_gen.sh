#!/bin/bash
CURRENT_DIR="$(pwd)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd $SCRIPT_DIR

gen_regex() {
    # Name of circuit to set
    circuit_name=$(echo "${1%.json}" | sed -r 's/(^|_)(.)/\U\2/g')
    # Name of file to set
    file_name="${1%.json}.nr"

    # Gen regex with matching
    # zk-regex decomposed \
    #     -d "$1" \
    #     --noir-file-path "../src/capture/$file_name" \
    #     -t "$circuit_name" \
    #     -g true \
    #     --sparse-array false \
    #     --use-common crate::common \
    #     --force-match false

    zk-regex decomposed \
        -d "$1" \
        --noir-file-path "../src/match/$file_name" \
        -t "$circuit_name" \
        -g false \
        --sparse-array false \
        --use-common crate::common \
        --force-match false
}

cd templates/

for file in *.json; do
    gen_regex "$file"
done


cd $CURRENT_DIR