import os
import shutil
import subprocess
import json
import re
import glob

# --- Configuration ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))

DEFAULT_MAX_HAYSTACK_LEN = 300
DEFAULT_MAX_MATCH_LEN = 300
SAVE_INPUTS_FOR_SUCCESSFUL_FAIL_CASES = (
    False  # Set to True to save inputs for successful fail cases
)

# --- Directories ---
SAMPLE_HAYSTACKS_DIR = os.path.join(PROJECT_ROOT, "noir", "common", "sample_haystacks")
GRAPHS_DIR = os.path.join(PROJECT_ROOT, "noir", "src", "templates", "graphs")
CIRCUITS_DIR = os.path.join(PROJECT_ROOT, "noir", "src", "templates", "circuits")
CIRCUIT_INPUTS_DIR = os.path.join(SAMPLE_HAYSTACKS_DIR, "circuit_inputs")


def check_jq():
    """Checks if jq is installed."""
    try:
        subprocess.run(
            ["jq", "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def generate_circuit_inputs():
    print("Phase 1: Generating circuit inputs...")
    unexpected_successes = []  # List to store unexpected successes

    for sample_json_file in glob.glob(os.path.join(SAMPLE_HAYSTACKS_DIR, "*.json")):
        if not os.path.isfile(sample_json_file):
            print(f"Skipping non-file: {sample_json_file}")
            continue

        template_name = os.path.basename(sample_json_file).replace(".json", "")
        print(f"Processing sample haystacks for: {template_name}")

        graph_path = os.path.join(GRAPHS_DIR, f"{template_name}_graph.json")
        if not os.path.isfile(graph_path):
            print(
                f"  Error: Graph file not found at {graph_path}. Skipping {template_name}."
            )
            continue

        try:
            with open(sample_json_file, "r") as f:
                sample_data = json.load(f)
        except json.JSONDecodeError as e:
            print(
                f"  Error: Could not parse JSON from {sample_json_file}: {e}. Skipping."
            )
            continue

        # Process "pass" cases
        pass_haystacks = sample_data.get("pass", [])
        if pass_haystacks:
            for index, haystack in enumerate(pass_haystacks):
                if not haystack:  # Skip empty haystacks
                    continue
                print(f"  Generating 'pass' input {index} for {template_name}...")
                output_circuit_input_json = os.path.join(
                    CIRCUIT_INPUTS_DIR, f"{template_name}_pass_{index}.json"
                )

                cmd = [
                    "cargo",
                    "run",
                    "--quiet",
                    "--bin",
                    "zk-regex",
                    "generate-circuit-input",
                    "--graph-path",
                    graph_path,
                    "--input",
                    haystack,
                    "--max-haystack-len",
                    str(DEFAULT_MAX_HAYSTACK_LEN),
                    "--max-match-len",
                    str(DEFAULT_MAX_MATCH_LEN),
                    "--output-file-path",
                    output_circuit_input_json,
                    "--proving-framework",
                    "noir",
                ]
                try:
                    # For pass cases, show cargo output by not capturing stdout/stderr
                    subprocess.run(cmd, check=True, cwd=PROJECT_ROOT)
                    print(f"    Successfully generated: {output_circuit_input_json}")
                except subprocess.CalledProcessError:
                    print(
                        f"    Error generating input for pass case: {template_name} - pass {index}"
                    )
        else:
            print(f"  No 'pass' cases found for {template_name}.")

        # Process "fail" cases
        fail_haystacks = sample_data.get("fail", [])
        if fail_haystacks:
            for index, haystack in enumerate(fail_haystacks):
                if not haystack:  # Skip empty haystacks
                    continue
                print(
                    f"  Attempting to generate 'fail' input {index} for {template_name} (expected to fail)..."
                )
                temp_fail_output = os.path.join(
                    CIRCUIT_INPUTS_DIR, f"{template_name}_fail_{index}_temp.json"
                )

                cmd = [
                    "cargo",
                    "run",
                    "--quiet",
                    "--bin",
                    "zk-regex",
                    "generate-circuit-input",
                    "--graph-path",
                    graph_path,
                    "--input",
                    haystack,
                    "--max-haystack-len",
                    str(DEFAULT_MAX_HAYSTACK_LEN),
                    "--max-match-len",
                    str(DEFAULT_MAX_MATCH_LEN),
                    "--output-file-path",
                    temp_fail_output,
                    "--proving-framework",
                    "noir",
                ]
                # Suppress output for fail cases, check return code
                process = subprocess.run(
                    cmd, capture_output=True, text=True, cwd=PROJECT_ROOT
                )

                if process.returncode != 0:
                    print(
                        f"    Input generation failed as expected for: {template_name} - fail {index}"
                    )
                    if os.path.exists(temp_fail_output):
                        os.remove(temp_fail_output)
                else:
                    warning_message = f"    Warning: Input generation SUCCEEDED for 'fail' case: {template_name} - fail {index}."
                    print(warning_message)
                    unexpected_successes.append(
                        f'  - Template: {template_name}, Fail Case Index: {index}, Haystack: "{haystack}"'
                    )
                    if SAVE_INPUTS_FOR_SUCCESSFUL_FAIL_CASES:
                        final_fail_output_name = os.path.join(
                            CIRCUIT_INPUTS_DIR,
                            f"{template_name}_fail_{index}_unexpected_success.json",
                        )
                        shutil.move(temp_fail_output, final_fail_output_name)
                        print(f"      Input saved to {final_fail_output_name}")
                    else:
                        if os.path.exists(temp_fail_output):
                            os.remove(temp_fail_output)
        else:
            print(f"  No 'fail' cases found for {template_name}.")
        print("---")
    return unexpected_successes  # Return the list


def add_tests_to_noir_circuits():
    print("Phase 2: Adding tests to Noir circuits...")
    for circuit_nr_file in glob.glob(os.path.join(CIRCUITS_DIR, "*_regex.nr")):
        if not os.path.isfile(circuit_nr_file):
            print(f"Skipping non-file: {circuit_nr_file}")
            continue

        template_name = os.path.basename(circuit_nr_file).replace("_regex.nr", "")
        print(f"Processing circuit: {circuit_nr_file} (template: {template_name})")

        try:
            with open(circuit_nr_file, "r") as f:
                circuit_content_lines = f.readlines()
        except IOError as e:
            print(f"  Error reading {circuit_nr_file}: {e}. Skipping.")
            continue

        # Replace "use zkregex::" with "use crate::"
        imports_modified = False
        for i, line in enumerate(circuit_content_lines):
            if line.strip().startswith("use zkregex::"):
                circuit_content_lines[i] = line.replace(
                    "use zkregex::", "use crate::", 1
                )
                imports_modified = True

        if imports_modified:
            print(f"  Updated 'use zkregex::' to 'use crate::' in {circuit_nr_file}.")

        # Remove existing #[cfg(test)] mod tests { ... } block
        mod_tests_removed = False
        mod_tests_start_index = -1
        for i, line in enumerate(circuit_content_lines):
            if (
                line.strip().startswith("#[cfg(test)]")
                and "mod tests"
                in circuit_content_lines[
                    i + 1 if i + 1 < len(circuit_content_lines) else i
                ].strip()
            ):  # check next line for mod tests {
                # A bit more robust check for typical formatting
                if "mod tests" in circuit_content_lines[
                    i + 1
                ].strip() and circuit_content_lines[i + 1].strip().endswith("{"):
                    mod_tests_start_index = i
                    break
            elif line.strip().startswith(
                "#[cfg(test)] mod tests"
            ):  # Handles cases where it's on one line
                mod_tests_start_index = i
                break

        if mod_tests_start_index != -1:
            brace_count = 0
            mod_tests_end_index = -1
            # Determine the start of the block for brace counting
            block_start_line_index = mod_tests_start_index
            # Find the opening brace '{'
            for i in range(mod_tests_start_index, len(circuit_content_lines)):
                if "{" in circuit_content_lines[i]:
                    block_start_line_index = i
                    break

            for i in range(block_start_line_index, len(circuit_content_lines)):
                brace_count += circuit_content_lines[i].count("{")
                brace_count -= circuit_content_lines[i].count("}")
                if (
                    brace_count == 0 and i >= block_start_line_index
                ):  # Ensure we've at least processed the line with the first {
                    # Check if the line where brace_count becomes 0 actually contained the first '{' of the mod tests
                    # This is to handle cases like `mod tests {}` on a single line correctly.
                    first_brace_on_this_line = (
                        True
                        if circuit_content_lines[i].count("{") > 0
                        and i == block_start_line_index
                        else False
                    )
                    if not (
                        first_brace_on_this_line
                        and circuit_content_lines[i].count("{")
                        > circuit_content_lines[i].count("}")
                    ):
                        mod_tests_end_index = i
                        break

            if mod_tests_end_index != -1:
                del circuit_content_lines[
                    mod_tests_start_index : mod_tests_end_index + 1
                ]
                mod_tests_removed = True
                print(f"  Removed existing 'mod tests {{ ... }}' block.")
            else:
                print(
                    f"  Warning: Found start of 'mod tests' but not its end. Manual check advised."
                )

        circuit_content_str = "".join(
            circuit_content_lines
        )  # Rebuild after potential removal

        lines_to_append_to_file = []
        globals_added_this_run = False

        # Check and prepare MAX_HAYSTACK_LEN and MAX_MATCH_LEN if not present globally
        if not re.search(
            r"^global MAX_HAYSTACK_LEN: u32\s*=\s*\d+;",
            circuit_content_str,
            re.MULTILINE,
        ):
            lines_to_append_to_file.append(
                f"global MAX_HAYSTACK_LEN: u32 = {DEFAULT_MAX_HAYSTACK_LEN};\n"
            )
            globals_added_this_run = True
            print(f"  Prepared global MAX_HAYSTACK_LEN = {DEFAULT_MAX_HAYSTACK_LEN}.")
        if not re.search(
            r"^global MAX_MATCH_LEN: u32\s*=\s*\d+;", circuit_content_str, re.MULTILINE
        ):
            lines_to_append_to_file.append(
                f"global MAX_MATCH_LEN: u32 = {DEFAULT_MAX_MATCH_LEN};\n"
            )
            globals_added_this_run = True
            print(f"  Prepared global MAX_MATCH_LEN = {DEFAULT_MAX_MATCH_LEN}.")

        if (
            globals_added_this_run and lines_to_append_to_file
        ):  # Add a newline after globals if they were added
            lines_to_append_to_file.append("\n")

        num_capture_groups_in_circuit = 0
        num_cg_match = re.search(
            r"pub global NUM_CAPTURE_GROUPS: u32\s*=\s*(\d+);", circuit_content_str
        )
        if num_cg_match:
            num_capture_groups_in_circuit = int(num_cg_match.group(1))

        pass_input_json_pattern = os.path.join(
            CIRCUIT_INPUTS_DIR, f"{template_name}_pass_*.json"
        )
        pass_input_json_files = glob.glob(pass_input_json_pattern)

        if (
            not pass_input_json_files
            and not globals_added_this_run
            and not imports_modified
            and not mod_tests_removed
        ):
            print(
                f"  No pass case circuit inputs found for {template_name} and no other changes. No tests added or file modified."
            )
            continue

        new_tests_generated_this_run = False
        for input_json_file in pass_input_json_files:
            index_match = re.search(
                rf"{template_name}_pass_(\d+)\.json$", input_json_file
            )
            if not index_match:
                continue
            index = index_match.group(1)
            test_fn_name = f"test_{template_name}_pass_{index}"

            # Check against the potentially modified circuit_content_str
            current_full_content = "".join(circuit_content_lines) + "".join(
                lines_to_append_to_file
            )
            if f"fn {test_fn_name}()" in current_full_content:
                print(
                    f"  Test function {test_fn_name} already exists or is pending. Skipping."
                )
                continue

            print(f"  Generating test function: {test_fn_name}")
            new_tests_generated_this_run = True

            try:
                with open(input_json_file, "r") as f:
                    input_data = json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                print(
                    f"    Error reading or parsing input JSON {input_json_file}: {e}. Skipping this test."
                )
                continue

            in_haystack_val_list = [str(x) for x in input_data.get("in_haystack", [])]
            in_haystack_val = ", ".join(in_haystack_val_list)
            match_start_val = input_data.get("match_start", 0)
            match_length_val = input_data.get("match_length", 0)
            curr_states_val = ", ".join(map(str, input_data.get("curr_states", [])))
            next_states_val = ", ".join(map(str, input_data.get("next_states", [])))

            test_fn_content_list = [
                f"#[test]",
                f"fn {test_fn_name}() {{",
                f"    let in_haystack: [u8; MAX_HAYSTACK_LEN] = [{in_haystack_val}];",
                f"    let match_start: u32 = {match_start_val};",
                f"    let match_length: u32 = {match_length_val};",
                f"    let current_states: [Field; MAX_MATCH_LEN] = [{curr_states_val}];",
                f"    let next_states: [Field; MAX_MATCH_LEN] = [{next_states_val}];",
            ]

            call_params = [
                "in_haystack",
                "match_start",
                "match_length",
                "current_states",
                "next_states",
            ]

            if num_capture_groups_in_circuit > 0:
                cg_start_indices = ", ".join(
                    map(
                        str,
                        input_data.get(
                            "capture_group_start_indices",
                            [0] * num_capture_groups_in_circuit,
                        ),
                    )
                )
                test_fn_content_list.append(
                    f"    let capture_group_start_indices_val: [Field; NUM_CAPTURE_GROUPS] = [{cg_start_indices}];"
                )

                cg_id_param_names = []
                cg_start_param_names = []
                for cg_idx in range(1, num_capture_groups_in_circuit + 1):
                    cg_ids_list = input_data.get("capture_group_ids", [])
                    cg_starts_list = input_data.get("capture_group_starts", [])
                    current_cg_ids_val = ""
                    if len(cg_ids_list) >= cg_idx:
                        current_cg_ids_val = ", ".join(
                            map(str, cg_ids_list[cg_idx - 1])
                        )
                    current_cg_starts_val = ""
                    if len(cg_starts_list) >= cg_idx:
                        current_cg_starts_val = ", ".join(
                            map(str, cg_starts_list[cg_idx - 1])
                        )
                    test_fn_content_list.append(
                        f"    let capture_group_{cg_idx}_id: [Field; MAX_MATCH_LEN] = [{current_cg_ids_val}];"
                    )
                    test_fn_content_list.append(
                        f"    let capture_group_{cg_idx}_start: [Field; MAX_MATCH_LEN] = [{current_cg_starts_val}];"
                    )
                    cg_id_param_names.append(f"capture_group_{cg_idx}_id")
                    cg_start_param_names.append(f"capture_group_{cg_idx}_start")

                call_params.extend(cg_id_param_names)
                call_params.extend(cg_start_param_names)
                call_params.append("capture_group_start_indices_val")

            call_params_str = ", ".join(call_params)
            regex_match_call_base = (
                f"regex_match::<MAX_HAYSTACK_LEN, MAX_MATCH_LEN>({call_params_str})"
            )

            if num_capture_groups_in_circuit == 1:
                capture_vars = "capture_1"
                test_fn_content_list.append(
                    f"    let {capture_vars} = {regex_match_call_base};"
                )
            elif num_capture_groups_in_circuit > 1:
                capture_vars_list = [
                    f"capture_{i}" for i in range(1, num_capture_groups_in_circuit + 1)
                ]
                capture_vars = f"({', '.join(capture_vars_list)})"
                test_fn_content_list.append(
                    f"    let {capture_vars} = {regex_match_call_base};"
                )
            else:
                test_fn_content_list.append(f"    {regex_match_call_base};")

            test_fn_content_list.append("}")
            lines_to_append_to_file.extend(
                [line + "\n" for line in test_fn_content_list]
            )
            lines_to_append_to_file.append(
                "\n"
            )  # Add a blank line after each test function

        # Determine if any actual code changes were made or are pending
        made_actual_changes = (
            imports_modified
            or mod_tests_removed
            or globals_added_this_run
            or new_tests_generated_this_run
        )

        if (
            lines_to_append_to_file or made_actual_changes
        ):  # Check if there's anything to append or if prior modifications happened
            # Append new lines to original content
            circuit_content_lines.extend(lines_to_append_to_file)
            try:
                with open(circuit_nr_file, "w") as f:
                    f.writelines(circuit_content_lines)
                print(f"  Successfully updated {circuit_nr_file}.")
            except IOError as e:
                print(f"  Error writing updated tests to {circuit_nr_file}: {e}")
        else:
            print(
                f"  No new tests were added and no modifications made to {circuit_nr_file}."
            )
        print("---")


def main():
    os.chdir(PROJECT_ROOT)
    print(f"Changed working directory to: {os.getcwd()}")

    if (
        not check_jq()
    ):  # Though jq is not directly used by Python, the script logic implies its earlier necessity
        print(
            "jq could not be found. While this Python script doesn't directly use jq for parsing,"
        )
        print(
            "the overall workflow might depend on it for other parts if not fully migrated."
        )
        # exit(1) # You might still want to exit if other parts of your system rely on jq

    os.makedirs(CIRCUIT_INPUTS_DIR, exist_ok=True)

    print("Starting input generation and test scaffolding...")
    print(f"Sample haystacks source: {SAMPLE_HAYSTACKS_DIR}")
    print(f"Graphs source: {GRAPHS_DIR}")
    print(f"Circuit inputs destination: {CIRCUIT_INPUTS_DIR}")
    print(f"Noir circuits to update: {CIRCUITS_DIR}")
    print("---")

    unexpected_fail_successes = generate_circuit_inputs()
    add_tests_to_noir_circuits()

    if unexpected_fail_successes:
        print("\n--- SUMMARY OF UNEXPECTED SUCCESSES FOR 'FAIL' CASES ---")
        print(
            "The following 'fail' cases unexpectedly resulted in successful input generation:"
        )
        for item in unexpected_fail_successes:
            print(item)
        print(
            "Please review these cases to ensure the regex and test data are correct."
        )
        print("---")

    print("Script finished.")


if __name__ == "__main__":
    main()
