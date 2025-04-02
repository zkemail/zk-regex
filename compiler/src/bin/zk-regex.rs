use clap::{Parser, Subcommand};
use compiler::{DecomposedRegexConfig, NFAGraph, compile, decomposed_to_composed_regex};
use heck::{ToPascalCase, ToSnakeCase};
use std::{fs::File, path::PathBuf};

#[derive(Parser)]
#[command(about = "ZK Regex Compiler CLI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Process a decomposed regex file
    Decomposed {
        /// Path to the decomposed regex JSON file
        #[arg(short, long)]
        decomposed_regex_path: PathBuf,

        /// Directory path for output files
        #[arg(short, long)]
        circom_file_path: PathBuf,

        /// Template name in PascalCase (e.g., TimestampRegex)
        #[arg(short, long, value_parser = validate_cli_template_name)]
        template_name: String,
    },

    /// Process a raw regex string
    Raw {
        /// Raw regex string
        #[arg(short, long)]
        raw_regex: String,

        /// Directory path for output files
        #[arg(short, long)]
        circom_file_path: PathBuf,

        /// Template name in PascalCase (e.g., TimestampRegex)
        #[arg(short, long, value_parser = validate_cli_template_name)]
        template_name: String,
    },

    /// Generate circuit inputs from a cached graph
    GenerateCircomInput {
        /// Path to the graph JSON file
        #[arg(short, long)]
        graph_path: PathBuf,

        /// Input string to match
        #[arg(short, long)]
        input: String,

        /// Maximum haystack length
        #[arg(short = 'h', long)]
        max_haystack_len: usize,

        /// Maximum match length
        #[arg(short = 'm', long)]
        max_match_len: usize,

        /// Output JSON file for circuit inputs
        #[arg(short, long)]
        output: PathBuf,
    },
}

fn validate_cli_template_name(name: &str) -> Result<String, String> {
    // Convert to PascalCase to normalize
    let pascal_name = name.to_pascal_case();

    // Verify it's valid PascalCase
    if pascal_name != name {
        return Err("Template name must be in PascalCase (e.g., ThisIsATemplate)".into());
    }

    Ok(name.to_string())
}

fn save_outputs(
    nfa: &NFAGraph,
    circom_code: String,
    output_dir: &PathBuf,
    template_name: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    validate_cli_template_name(template_name)?;

    // Create output directory if it doesn't exist
    std::fs::create_dir_all(output_dir)?;

    let snake_case_name = template_name.to_snake_case();

    // Save Circom file
    let circom_path = output_dir.join(format!("{}_regex.circom", snake_case_name));
    std::fs::write(&circom_path, circom_code)?;

    // Save graph JSON
    let graph_json = nfa.to_json()?;
    let graph_path = output_dir.join(format!("{}_graph.json", snake_case_name));
    std::fs::write(&graph_path, graph_json)?;

    println!("Generated files:");
    println!("  Circuit: {}", circom_path.display());
    println!("  Graph: {}", graph_path.display());

    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Decomposed {
            decomposed_regex_path,
            circom_file_path,
            template_name,
        } => {
            let config: DecomposedRegexConfig =
                serde_json::from_reader(File::open(decomposed_regex_path)?)?;

            let (combined_pattern, max_bytes) = decomposed_to_composed_regex(&config);

            let nfa = compile(&combined_pattern)?;

            let circom_code = if !max_bytes.is_empty() {
                nfa.generate_circom_code(&template_name, &combined_pattern, Some(&max_bytes))?
            } else {
                nfa.generate_circom_code(&template_name, &combined_pattern, None)?
            };

            save_outputs(&nfa, circom_code, &circom_file_path, &template_name)?;
        }

        Commands::Raw {
            raw_regex,
            circom_file_path,
            template_name,
        } => {
            let nfa = compile(&raw_regex)?;
            let circom_code = nfa.generate_circom_code(&template_name, &raw_regex, None)?;

            save_outputs(&nfa, circom_code, &circom_file_path, &template_name)?;
        }

        Commands::GenerateCircomInput {
            graph_path,
            input,
            max_haystack_len,
            max_match_len,
            output,
        } => {
            // Load the cached graph
            let graph_json = std::fs::read_to_string(graph_path)?;
            let nfa = NFAGraph::from_json(&graph_json)?;

            // Generate circuit inputs
            let inputs = nfa.generate_circom_inputs(&input, max_len)?;

            // Save inputs
            let input_json = serde_json::to_string_pretty(&inputs)?;
            std::fs::write(&output, input_json)?;

            println!("Generated circuit inputs: {}", output.display());
        }
    }

    Ok(())
}
