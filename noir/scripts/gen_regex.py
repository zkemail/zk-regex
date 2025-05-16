import os
import shutil
import subprocess
import re

# --- Configuration ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(
    os.path.join(SCRIPT_DIR, "..", "..")
)  # Navigate to project root

# --- Directories ---
NOIR_COMMON_DIR = os.path.join(PROJECT_ROOT, "noir", "common")
CIRCUITS_DIR = os.path.join(PROJECT_ROOT, "noir", "src", "templates", "circuits")
GRAPHS_DIR = os.path.join(PROJECT_ROOT, "noir", "src", "templates", "graphs")
TEMP_OUTPUT_DIR = os.path.join(PROJECT_ROOT, "noir", "src", "templates", "temp_gen")


def to_snake_case(name):
    """Converts PascalCase or camelCase to snake_case."""
    s1 = re.sub("(.)([A-Z][a-z]+)", r"\1_\2", name)
    return re.sub("([a-z0-9])([A-Z])", r"\1_\2", s1).lower()


def generate_files(regex_json_path):
    template_name = os.path.basename(regex_json_path).replace(".json", "")

    # The bash script uses Perl for PascalCase.
    # Python equivalent for simple 'a_b_c' -> 'ABC' or 'a-b-c' -> 'ABC'
    # If the original template_name from the file is already PascalCase or suitable,
    # this conversion might be simpler or unnecessary depending on compiler needs.
    # For now, mimicing the idea of ensuring some form of non-snake_case for the compiler.
    # A common Python way for "PascalCase" from "snake_case" or "kebab-case":
    parts = re.split("_|-", template_name)
    template_name_pascal = "".join(word.capitalize() for word in parts)
    # If template_name was already PascalCase (e.g. "EmailDomain"), the above would make it "Emaildomain"
    # So, let's refine this to be closer to the `perl -pe 's/(^|_)(.)/\U$2/g'`
    # which effectively capitalizes after each underscore and the start.
    # If `template_name` is `email_domain`, `template_name_pascal` should be `EmailDomain`
    # If `template_name` is `emaildomain`, `template_name_pascal` should be `Emaildomain` (this is common)
    # The perl `\U$2` uppercases the matched character.

    # Let's use a more direct PascalCase conversion logic if input is snake_case
    if "_" in template_name:
        template_name_pascal = "".join(
            word.capitalize() for word in template_name.split("_")
        )
    elif "-" in template_name:  # Handle kebab-case as well
        template_name_pascal = "".join(
            word.capitalize() for word in template_name.split("-")
        )
    else:  # Assume it might be single word or already camel/pascal
        template_name_pascal = (
            template_name[0].upper() + template_name[1:]
            if len(template_name) > 1
            else template_name.upper()
        )

    print(
        f"Processing {template_name} (from {regex_json_path}), using template name for compiler: {template_name_pascal}"
    )

    print(f"Generating files for {template_name_pascal}...")
    try:
        # Note: subprocess.run with shell=True can be a security risk if parts of the command are from untrusted input.
        # Here, paths and names are derived from controlled sources, but it's good practice to be aware.
        # Using a list of arguments is safer.
        cmd = [
            "cargo",
            "run",
            "--bin",
            "zk-regex",
            "decomposed",
            "--decomposed-regex-path",
            regex_json_path,
            "--output-file-path",
            TEMP_OUTPUT_DIR,
            "--template-name",
            template_name_pascal,
            "--proving-framework",
            "noir",
        ]
        # To see output, remove capture_output=True, text=True
        # process = subprocess.run(cmd, check=True, capture_output=True, text=True, cwd=PROJECT_ROOT)
        process = subprocess.run(
            cmd, check=True, cwd=PROJECT_ROOT
        )  # Show output from cargo
        print(f"  Cargo command executed successfully for {template_name_pascal}.")

    except subprocess.CalledProcessError as e:
        print(f"  Error running cargo for {template_name_pascal}: {e}")
        # print(f"  Stdout: {e.stdout}")
        # print(f"  Stderr: {e.stderr}")
        return  # Skip moving files if generation failed

    # Determine the base name the compiler likely used for output files.
    # The compiler is expected to convert the --template-name (PascalCase) to snake_case.
    compiled_file_base_name = to_snake_case(template_name_pascal)

    generated_regex_nr_source = os.path.join(
        TEMP_OUTPUT_DIR, f"{compiled_file_base_name}_regex.nr"
    )
    generated_graph_json_source = os.path.join(
        TEMP_OUTPUT_DIR, f"{compiled_file_base_name}_graph.json"
    )

    # Target files should use the original template_name from the .json file (which is already snake_case or simple)
    target_regex_nr = os.path.join(CIRCUITS_DIR, f"{template_name}_regex.nr")
    target_graph_json = os.path.join(GRAPHS_DIR, f"{template_name}_graph.json")

    # Move the generated regex.nr file
    if os.path.exists(generated_regex_nr_source):
        shutil.move(generated_regex_nr_source, target_regex_nr)
        print(f"Moved {generated_regex_nr_source} to {target_regex_nr}")
    else:
        print(f"Error: Generated regex file {generated_regex_nr_source} not found!")
        print(f"Attempted base name for compiler output: {compiled_file_base_name}")

    # Move the generated graph.json file
    if os.path.exists(generated_graph_json_source):
        shutil.move(generated_graph_json_source, target_graph_json)
        print(f"Moved {generated_graph_json_source} to {target_graph_json}")
    else:
        print(f"Warning: Generated graph file {generated_graph_json_source} not found.")
        print(f"Attempted base name for compiler output: {compiled_file_base_name}")
    print("---")


def main():
    # Change current working directory to project root
    os.chdir(PROJECT_ROOT)
    print(f"Changed working directory to: {os.getcwd()}")

    if not os.path.isdir(NOIR_COMMON_DIR):
        print(f"Error: Directory {NOIR_COMMON_DIR} not found.")
        exit(1)

    os.makedirs(CIRCUITS_DIR, exist_ok=True)
    os.makedirs(GRAPHS_DIR, exist_ok=True)
    os.makedirs(TEMP_OUTPUT_DIR, exist_ok=True)

    print(f"Target circuits directory: {CIRCUITS_DIR}")
    print(f"Target graphs directory: {GRAPHS_DIR}")

    for filename in os.listdir(NOIR_COMMON_DIR):
        if filename.endswith(".json"):
            regex_json_file = os.path.join(NOIR_COMMON_DIR, filename)
            if os.path.isfile(regex_json_file):
                generate_files(regex_json_file)

    # Clean up temporary directory
    if os.path.isdir(TEMP_OUTPUT_DIR):
        print(f"Cleaning up temporary directory: {TEMP_OUTPUT_DIR}")
        # shutil.rmtree is powerful, ensure TEMP_OUTPUT_DIR is correct.
        if (
            TEMP_OUTPUT_DIR
            and TEMP_OUTPUT_DIR != "/"
            and os.path.basename(TEMP_OUTPUT_DIR) == "temp_gen"
        ):
            shutil.rmtree(TEMP_OUTPUT_DIR)
        else:
            print(
                f"Error: TEMP_OUTPUT_DIR ('{TEMP_OUTPUT_DIR}') is not set safely or not as expected. Aborting cleanup."
            )

    print("Script finished.")


if __name__ == "__main__":
    main()
