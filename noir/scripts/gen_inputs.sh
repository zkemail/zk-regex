#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../../"

# Input args for the script
set_inputs_to_use() {
    local template="$1"
    
    case "$template" in
        "timestamp")
            HAYSTACK=$(echo -e "dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=;\x00")
            MAX_HAYSTACK_LEN=300
            MAX_MATCH_LEN=100
            ;;
        "simple")
            HAYSTACK=aaaaaaab
            MAX_HAYSTACK_LEN=10
            MAX_MATCH_LEN=10
            ;;
        "subject_all")
            HAYSTACK=$(echo -e "\r\nsubject: this si a buject\r\n ")
            MAX_HAYSTACK_LEN=50
            MAX_MATCH_LEN=50
            ;;
        *)
            echo "Error: Invalid template '$template' supplied" >&2
            folders=$(find ./noir/templates -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | awk '{print "\""$0"\""}' | paste -sd ", " -)
            echo "Valid temlates are: $folders" >&2
            return 0
            ;;
    esac
}

gen_prover_toml() {
    local template="$1"

    cargo run \
        --bin zk-regex generate-circuit-input \
        --graph-path ./noir/templates/$template/${template}_graph.json \
        --input "$HAYSTACK" \
        --max-haystack-len "$MAX_HAYSTACK_LEN" \
        --max-match-len "$MAX_MATCH_LEN" \
        --output ./noir/templates/$template/Prover.toml \
        --noir true
}

transform_inputs() {
    local template_path="$1"
    local prover_toml_file="$1/Prover.toml"
    local transformed_inputs_file="$1/inputs.txt"

    # If the transformed_inputs_file exists, delete it
    if [ -f "$transformed_inputs_file" ]; then
        rm "$transformed_inputs_file"
    fi

    while IFS= read -r line || [ -n "$line" ]; do

    # Skip empty lines
    if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
        continue
    fi
    
    # Transform the line
    # 1. Add "let " prefix
    # 2. Remove double quotes
    # 3. Add semicolon at the end
    transformed_line="let ${line//\"}"
    
    # Skip if the line doesn't contain an equals sign
    if [[ ! "$transformed_line" =~ "=" ]]; then
        continue
    fi
    
    echo "$transformed_line;" >> "$transformed_inputs_file"
    done < "$prover_toml_file"
}

## Ensure an argument is provided
if [ $# -ne 1 ]; then
    echo "ERROR: Supply the template name you'd like to generate sample inputs for" >&2
    folders=$(find ./noir/templates -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | awk '{print "\""$0"\""}' | paste -sd ", " -)
    echo "Available templates: $folders" >&2
    echo "" >&2
    echo "Usage: $0 <template>" >&2
    echo "" >&2
    echo "Example: $0 simple" >&2
    exit 1
fi

## Ensure the argument is a provided regex template
template_arg="$1"
template_found=0

template_folders=$(find ./noir/templates -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

for folder in $template_folders; do
    if [ "$folder" = "$template_arg" ]; then
        template_found=1
        # If found, generate the inputs
        echo "Generating inputs for $template_arg..."
        # set the inputs
        set_inputs_to_use "$template_arg"
        # generate the prover.toml
        gen_prover_toml "$template_arg"
        # transform inputs for easy integration with tests
        transform_inputs "./noir/templates/$template_arg"

        echo "=========================="
        echo "Inputs generated for $template_arg"
        echo "Prover.toml saved to ./noir/templates/$template_arg/Prover.toml (use for proving from cli)"
        echo "Formatted inputs saved to ./noir/templates/$template_arg/inputs.txt (copy paste into tests)"
    fi
done

if [ $template_found -eq 0 ]; then
    echo "ERROR: Template '$template_arg' not found!" >&2
    folders=$(find ./noir/templates -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | awk '{print "\""$0"\""}' | paste -sd ", " -)
    echo "Available templates: $folders" >&2
    exit 1
fi