#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../../" # Navigate to project root

# Ensure noir/common directory exists
NOIR_COMMON_DIR="./noir/common"
if [ ! -d "$NOIR_COMMON_DIR" ]; then
    echo "Error: Directory $NOIR_COMMON_DIR not found."
    exit 1
fi

# Define output directories for circuits and graphs
CIRCUITS_DIR="./noir/templates/circuits"
GRAPHS_DIR="./noir/templates/graphs"
TEMP_OUTPUT_DIR="./noir/templates/temp_gen" # Intermediate directory for compiler output

# Create the target directories if they don't exist
mkdir -p "$CIRCUITS_DIR"
mkdir -p "$GRAPHS_DIR"
mkdir -p "$TEMP_OUTPUT_DIR"

echo "Target circuits directory: $CIRCUITS_DIR"
echo "Target graphs directory: $GRAPHS_DIR"

generate_files() {
    local regex_json_path=$1
    local template_name=$(basename "$regex_json_path" .json)
    # Using Perl for a potentially more robust PascalCase conversion.
    # If your compiler doesn't strictly need PascalCase for --template-name,
    # you can simplify by using template_name directly.
    local template_name_pascal=$(echo "$template_name" | perl -pe 's/(^|_)(.)/\U$2/g')
    # If you prefer to not use PascalCase for the compiler's template name:
    # local template_name_pascal="$template_name" 
    
    echo "Processing $template_name (from $regex_json_path), using template name for compiler: $template_name_pascal"

    # Generate regex.nr and graph.json files into a temporary location
    echo "Generating files for $template_name_pascal..."
    cargo run \
        --bin zk-regex decomposed \
        --decomposed-regex-path "$regex_json_path" \
        --output-file-path "$TEMP_OUTPUT_DIR" \
        --template-name "$template_name_pascal" \
        --proving-framework noir
    
    # Compiler is expected to create files like <template_name>_regex.nr and <template_name>_graph.json
    # using the snake_case version of the template_name_pascal IT receives.
    # So if template_name_pascal is "Succinct", it creates "succinct_regex.nr".
    # If template_name_pascal is "succinct", it also creates "succinct_regex.nr".
    local compiled_file_base_name=$(echo "$template_name_pascal" | perl -pe 's/([A-Z]+)/_\L$1/g; s/^_//') 
    # Adjust if template_name_pascal is already snake_case
    if [[ "$template_name_pascal" != *_* && "$template_name_pascal" =~ [a-z] && ! "$template_name_pascal" =~ [A-Z] ]]; then
      compiled_file_base_name="$template_name_pascal"
    fi


    local generated_regex_nr_source="${TEMP_OUTPUT_DIR}/${compiled_file_base_name}_regex.nr"
    local generated_graph_json_source="${TEMP_OUTPUT_DIR}/${compiled_file_base_name}_graph.json"

    # Target files should use the original template_name from the .json file
    local target_regex_nr="${CIRCUITS_DIR}/${template_name}_regex.nr"
    local target_graph_json="${GRAPHS_DIR}/${template_name}_graph.json"

    # Move the generated regex.nr file
    if [ -f "$generated_regex_nr_source" ]; then
        mv "$generated_regex_nr_source" "$target_regex_nr"
        echo "Moved $generated_regex_nr_source to $target_regex_nr"
    else
        echo "Error: Generated regex file $generated_regex_nr_source not found!"
        echo "Attempted base name for compiler output: $compiled_file_base_name"
    fi

    # Move the generated graph.json file
    if [ -f "$generated_graph_json_source" ]; then
        mv "$generated_graph_json_source" "$target_graph_json"
        echo "Moved $generated_graph_json_source to $target_graph_json"
    else
        echo "Warning: Generated graph file $generated_graph_json_source not found."
        echo "Attempted base name for compiler output: $compiled_file_base_name"
    fi
    echo "---"
}

# Iterate over *.json files in noir/common/
for regex_json_file in "$NOIR_COMMON_DIR"/*.json; do
    if [ -f "$regex_json_file" ]; then # Check if it's a file
        generate_files "$regex_json_file"
    fi
done

# Clean up temporary directory
if [ -d "$TEMP_OUTPUT_DIR" ]; then
    echo "Cleaning up temporary directory: $TEMP_OUTPUT_DIR"
    # Use rm -rf carefully. Ensure TEMP_OUTPUT_DIR is what you expect.
    # Add a check to prevent deleting unintended directories if $TEMP_OUTPUT_DIR is empty or '/'.
    if [ -n "$TEMP_OUTPUT_DIR" ] && [ "$TEMP_OUTPUT_DIR" != "/" ]; then
        rm -r "$TEMP_OUTPUT_DIR"
    else
        echo "Error: TEMP_OUTPUT_DIR is not set safely. Aborting cleanup."
    fi
fi

echo "Script finished."
