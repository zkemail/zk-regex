#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../../"

codegen_regex() {
    local template_name=$1
    local template_name_pascal=$(echo "$template_name" | sed -r 's/(^|_)(.)/\U\2/g')
    echo "Generating regex circuit for $template_name"
    
    cargo run \
        --bin zk-regex decomposed \
        --decomposed-regex-path "./noir/templates/${template_name}/${template_name}.json" \
        --output-file-path ./noir/templates/${template_name} \
        --template-name "$template_name_pascal" \
        --noir
    
    mv ./noir/templates/${template_name}/${template_name}_regex.nr ./noir/src/common/${template_name}_regex.nr
    sed -i 's/zkregex/crate/g' ./noir/src/common/${template_name}_regex.nr
}

for dir in ./noir/templates/*; do
    if [ -d "$dir" ]; then
        template_name=$(basename "$dir")
        codegen_regex "$template_name"
    else
        echo "Skipping non-directory: $dir"
    fi
done
