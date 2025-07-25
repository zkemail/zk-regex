import os
import subprocess
import re


def to_pascal_case(text):
    """Converts a snake_case or kebab-case string to PascalCase."""
    # Replace hyphens with underscores, then split by underscores
    s = re.sub(r"[-_]+", "_", text)
    return "".join(word.capitalize() for word in s.split("_"))


def main():
    # Corrected project_root calculation
    # __file__ is circom/scripts/gen_regex.py
    # os.path.dirname(__file__) is circom/scripts/
    # os.path.join(os.path.dirname(__file__), "..", "..") goes up two levels
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

    # Adjust these paths if your script's location is different
    # relative to the zk-regex project root
    compiler_executable = os.path.join(project_root, "target", "release", "zk-regex")
    regex_dir = os.path.join(project_root, "circom", "regexes")
    output_dir = os.path.join(project_root, "circom", "circuits", "common")
    proving_framework = "circom"

    if not os.path.exists(compiler_executable):
        print(f"Error: Compiler executable not found at {compiler_executable}")
        print(
            "Please build the compiler first (e.g., cargo build in the compiler directory)."
        )
        return

    if not os.path.isdir(regex_dir):
        print(f"Error: Regex directory not found at {regex_dir}")
        return

    os.makedirs(output_dir, exist_ok=True)
    print(f"Ensured output directory exists: {output_dir}")

    print(f"Scanning for JSON files in: {regex_dir}")
    for filename in os.listdir(regex_dir):
        if filename.endswith(".json"):
            json_file_path = os.path.join(regex_dir, filename)
            base_name = os.path.splitext(filename)[0]

            # Convert base_name to PascalCase and append "Regex"
            # e.g., "email_address" -> "EmailAddressRegex"
            # e.g., "simple" -> "SimpleRegex"
            template_name = to_pascal_case(base_name)

            print(f"\nProcessing {filename}...")
            print(f"  Input JSON: {json_file_path}")
            print(f"  Template Name: {template_name}")
            print(f"  Output Directory: {output_dir}")

            command = [
                compiler_executable,
                "decomposed",
                "-d",
                json_file_path,
                "-o",
                output_dir,
                "-t",
                template_name,
                "-p",
                proving_framework,
            ]

            try:
                print(f"  Executing: {' '.join(command)}")
                process = subprocess.run(
                    command, capture_output=True, text=True, check=True
                )
                print("  Compiler Output:")
                if process.stdout:
                    for line in process.stdout.strip().split("\n"):
                        print(f"    STDOUT: {line}")
                if process.stderr:
                    for line in process.stderr.strip().split("\n"):
                        print(
                            f"    STDERR: {line}"
                        )  # Compiler warnings might go to stderr
                print(f"  Successfully generated files for {template_name}")

            except subprocess.CalledProcessError as e:
                print(f"  Error processing {filename}:")
                print(f"    Return code: {e.returncode}")
                if e.stdout:
                    print("    Stdout:")
                    for line in e.stdout.strip().split("\n"):
                        print(f"      {line}")
                if e.stderr:
                    print("    Stderr:")
                    for line in e.stderr.strip().split("\n"):
                        print(f"      {line}")
            except Exception as e:
                print(f"  An unexpected error occurred with {filename}: {e}")

    print("\nScript finished.")


if __name__ == "__main__":
    main()
