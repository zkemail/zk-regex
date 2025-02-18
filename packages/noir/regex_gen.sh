#!/bin/bash
CURRENT_DIR="$(pwd)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd $SCRIPT_DIR

gen_regex() {
    # Name of circuit to set
    circuit_name=$(echo "${1%.json}" | sed -r 's/(^|_)(.)/\U\2/g')
    # Name of file to set
    file_name="${1%.json}_regex.nr"

    # Gen regex
    zk-regex decomposed \
        -d "$1" \
        --noir-file-path "../$file_name" \
        -t "$circuit_name" \
        -g true \
        --sparse-array false \
        --use-common crate::common \
        --force-match false
}

cd src/templates/

for file in *.json; do
    gen_regex "$file"
done


cd $CURRENT_DIR