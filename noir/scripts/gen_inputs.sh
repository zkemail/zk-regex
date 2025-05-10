#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../../" # Navigate to project root

# --- Configuration ---
DEFAULT_MAX_HAYSTACK_LEN=300
DEFAULT_MAX_MATCH_LEN=100
# For "fail" cases, if generate-circuit-input succeeds, set to true to save the inputs anyway
SAVE_INPUTS_FOR_SUCCESSFUL_FAIL_CASES=false

# --- Directories ---
SAMPLE_HAYSTACKS_DIR="./noir/common/sample_haystacks"
GRAPHS_DIR="./noir/templates/graphs"
CIRCUITS_DIR="./noir/templates/circuits"
CIRCUIT_INPUTS_DIR="${SAMPLE_HAYSTACKS_DIR}/circuit_inputs"

# --- Setup ---
mkdir -p "$CIRCUIT_INPUTS_DIR"

if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq to run this script."
    exit 1
fi

echo "Starting input generation and test scaffolding..."
echo "Sample haystacks source: $SAMPLE_HAYSTACKS_DIR"
echo "Graphs source: $GRAPHS_DIR"
echo "Circuit inputs destination: $CIRCUIT_INPUTS_DIR"
echo "Noir circuits to update: $CIRCUITS_DIR"
echo "---"

# Phase 1: Generate Circuit Inputs
echo "Phase 1: Generating circuit inputs..."
for sample_json_file in "$SAMPLE_HAYSTACKS_DIR"/*.json; do
    if [ ! -f "$sample_json_file" ]; then
        echo "Skipping non-file (or no files found): $sample_json_file"
        continue
    fi

    template_name=$(basename "$sample_json_file" .json)
    echo "Processing sample haystacks for: $template_name"

    graph_path="${GRAPHS_DIR}/${template_name}_graph.json"
    if [ ! -f "$graph_path" ]; then
        echo "  Error: Graph file not found at $graph_path. Skipping $template_name."
        continue
    fi

    # Process "pass" cases
    pass_haystacks=$(jq -r '.pass[]?' "$sample_json_file")
    if [ -n "$pass_haystacks" ]; then
        index=0
        while IFS= read -r haystack; do
            if [ -z "$haystack" ]; then continue; fi
            echo "  Generating 'pass' input $index for $template_name..."
            output_circuit_input_json="${CIRCUIT_INPUTS_DIR}/${template_name}_pass_${index}.json"
            
            cargo run --quiet --bin zk-regex generate-circuit-input \
                --graph-path "$graph_path" \
                --input "$haystack" \
                --max-haystack-len "$DEFAULT_MAX_HAYSTACK_LEN" \
                --max-match-len "$DEFAULT_MAX_MATCH_LEN" \
                --output-file-path "$output_circuit_input_json" \
                --proving-framework noir
            
            if [ $? -eq 0 ]; then
                echo "    Successfully generated: $output_circuit_input_json"
            else
                echo "    Error generating input for pass case: $template_name - pass $index"
            fi
            index=$((index + 1))
        done <<< "$pass_haystacks"
    else
        echo "  No 'pass' cases found for $template_name."
    fi

    # Process "fail" cases
    fail_haystacks=$(jq -r '.fail[]?' "$sample_json_file")
    if [ -n "$fail_haystacks" ]; then
        index=0
        while IFS= read -r haystack; do
            if [ -z "$haystack" ]; then continue; fi
            echo "  Attempting to generate 'fail' input $index for $template_name (expected to fail)..."
            # For fail cases, we don't specify an output file unless we want to save unexpected successes
            
            temp_fail_output="${CIRCUIT_INPUTS_DIR}/${template_name}_fail_${index}_temp.json"

            cargo run --quiet --bin zk-regex generate-circuit-input \
                --graph-path "$graph_path" \
                --input "$haystack" \
                --max-haystack-len "$DEFAULT_MAX_HAYSTACK_LEN" \
                --max-match-len "$DEFAULT_MAX_MATCH_LEN" \
                --output-file-path "$temp_fail_output" \
                --proving-framework noir &> /dev/null # Suppress stdout for fail, check exit code
            
            if [ $? -ne 0 ]; then
                echo "    Input generation failed as expected for: $template_name - fail $index"
                rm -f "$temp_fail_output" # Clean up if it was created despite error
            else
                echo "    Warning: Input generation SUCCEEDED for 'fail' case: $template_name - fail $index."
                if [ "$SAVE_INPUTS_FOR_SUCCESSFUL_FAIL_CASES" = true ]; then
                     mv "$temp_fail_output" "${CIRCUIT_INPUTS_DIR}/${template_name}_fail_${index}_unexpected_success.json"
                     echo "      Input saved to ${CIRCUIT_INPUTS_DIR}/${template_name}_fail_${index}_unexpected_success.json"
                else
                     rm -f "$temp_fail_output"
                fi
            fi
            index=$((index + 1))
        done <<< "$fail_haystacks"
    else
        echo "  No 'fail' cases found for $template_name."
    fi
    echo "---"
done

# Phase 2: Add Tests to Noir Circuits
echo "Phase 2: Adding tests to Noir circuits..."
for circuit_nr_file in "$CIRCUITS_DIR"/*.nr; do
    if [ ! -f "$circuit_nr_file" ]; then
        echo "Skipping non-file (or no .nr files found): $circuit_nr_file"
        continue
    fi

    template_name=$(basename "$circuit_nr_file" _regex.nr)
    echo "Processing circuit: $circuit_nr_file (template: $template_name)"

    # Ensure `mod tests` block exists
    if ! grep -q -E "^#\[cfg\(test\)\](\s*)mod tests(\s*)\{" "$circuit_nr_file"; then
        echo -e "\n#[cfg(test)]\nmod tests {\n}" >> "$circuit_nr_file"
        echo "  Appended mod tests {} block."
    fi

    num_capture_groups_in_circuit=0
    if grep -q "pub global NUM_CAPTURE_GROUPS: u32" "$circuit_nr_file"; then
        num_capture_groups_in_circuit=$(grep "pub global NUM_CAPTURE_GROUPS: u32" "$circuit_nr_file" | awk -F'= ' '{print $2}' | sed 's/;//')
    fi

    pass_input_json_files=$(ls "${CIRCUIT_INPUTS_DIR}/${template_name}_pass_"*.json 2>/dev/null)
    if [ -z "$pass_input_json_files" ]; then
        echo "  No pass case circuit inputs found for $template_name. No tests added."
        continue
    fi
    
    for input_json_file in $pass_input_json_files; do
        index=$(echo "$input_json_file" | sed -n "s/.*${template_name}_pass_\\([0-9]*\\).json/\\1/p")
        test_fn_name="test_${template_name}_pass_${index}"

        # Check if test function already exists
        if grep -q "fn $test_fn_name()" "$circuit_nr_file"; then
            echo "  Test function $test_fn_name already exists. Skipping."
            continue
        fi

        echo "  Generating test function: $test_fn_name"

        # Parse inputs from JSON - this is complex to do robustly in pure bash for all data types
        # For simplicity, this example will assume jq can format them into a semi-usable string
        # A more robust solution might involve a small script (Python, Node.js) for this transformation

        in_haystack_val=$(jq '.in_haystack | map(tostring + "u8") | join(", ")' "$input_json_file")
        match_start_val=$(jq '.match_start' "$input_json_file")
        match_length_val=$(jq '.match_length' "$input_json_file")
        curr_states_val=$(jq '.curr_states | join(", ")' "$input_json_file")
        next_states_val=$(jq '.next_states | join(", ")' "$input_json_file")
        
        test_fn_content="\n    #[test]\n    fn ${test_fn_name}() {\n"
        test_fn_content+="        let in_haystack: [u8; MAX_HAYSTACK_LEN] = [${in_haystack_val}];\n" # MAX_HAYSTACK_LEN is global in circuit
        test_fn_content+="        let match_start: u32 = ${match_start_val};\n"
        test_fn_content+="        let match_length: u32 = ${match_length_val};\n"
        test_fn_content+="        let current_states: [Field; MAX_MATCH_LEN] = [${curr_states_val}];\n" # MAX_MATCH_LEN is global
        test_fn_content+="        let next_states: [Field; MAX_MATCH_LEN] = [${next_states_val}];\n"

        # Parameters for regex_match call
        call_params="in_haystack, match_start, match_length, current_states, next_states"

        if [ "$num_capture_groups_in_circuit" -gt 0 ]; then
             test_fn_content+="        let capture_group_start_indices_val: [Field; NUM_CAPTURE_GROUPS] = $(jq '.capture_group_start_indices // [] | join(", ")' "$input_json_file");\n" # NUM_CAPTURE_GROUPS global

            for (( cg_idx=1; cg_idx<=$num_capture_groups_in_circuit; cg_idx++ )); do
                cg_ids_val=$(jq ".capture_group_ids[$(($cg_idx-1))] // [] | join(\", \")" "$input_json_file")
                cg_starts_val=$(jq ".capture_group_starts[$(($cg_idx-1))] // [] | join(\", \")" "$input_json_file")
                
                test_fn_content+="        let capture_group_${cg_idx}_id: [Field; MAX_MATCH_LEN] = [${cg_ids_val}];\n"
                test_fn_content+="        let capture_group_${cg_idx}_start: [Field; MAX_MATCH_LEN] = [${cg_starts_val}];\n"
                
                call_params+=", capture_group_${cg_idx}_id, capture_group_${cg_idx}_start"
            done
            call_params+=", capture_group_start_indices_val"
        fi

        # Constructing the regex_match call and potential destructuring of captures
        if [ "$num_capture_groups_in_circuit" -gt 0 ]; then
            capture_vars="("
            for (( cg_idx=1; cg_idx<=$num_capture_groups_in_circuit; cg_idx++ )); do
                capture_vars+="capture_${cg_idx}"
                if [ $cg_idx -lt $num_capture_groups_in_circuit ]; then capture_vars+=", "; fi
            done
            capture_vars+=")"
            test_fn_content+="        let ${capture_vars} = super::regex_match(${call_params});\n"
            # TODO: Add assertions for capture values if available/needed
            # For now, just checking if it runs. Example:
            # test_fn_content+="        // assert_eq(capture_1.len(), EXPECTED_LEN_1);\n"
        else
            test_fn_content+="        super::regex_match(${call_params}); // Call for side-effects (assertions within) or ignore return\n"
        fi
        
        test_fn_content+="    }\n"

        # Insert the test function into the mod tests block
        
        # Create a temporary file for the test function content
        # test_fn_content is built with literal \n characters for newlines.
        # echo -e interprets these into actual newlines when writing to the temp file.
        TEMP_TEST_FN_FILE=$(mktemp)
        echo -e "${test_fn_content}" > "$TEMP_TEST_FN_FILE"

        # Use sed's 'r' command to read the content from the temporary file
        # and insert it after the line matching "/^mod tests {/".
        # This correctly places the test function inside the "mod tests {}" block.
        sed -i.bak "/^mod tests {/r ${TEMP_TEST_FN_FILE}" "$circuit_nr_file"
        
        rm -f "$TEMP_TEST_FN_FILE" # Clean up the temporary file
        rm -f "${circuit_nr_file}.bak" # Remove the backup file created by sed -i
        
        echo "    Appended test $test_fn_name."
    done
    echo "---"
done

echo "Script finished."