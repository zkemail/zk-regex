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
        output_file_path: PathBuf,

        /// Template name in PascalCase (e.g., TimestampRegex)
        #[arg(short, long, value_parser = validate_cli_template_name)]
        template_name: String,

        /// Noir boolean
        #[arg(long)]
        noir: bool,
    },

    /// Process a raw regex string
    Raw {
        /// Raw regex string
        #[arg(short, long)]
        raw_regex: String,

        /// Directory path for output files
        #[arg(short, long)]
        output_file_path: PathBuf,

        /// Template name in PascalCase (e.g., TimestampRegex)
        #[arg(short, long, value_parser = validate_cli_template_name)]
        template_name: String,

        /// Noir boolean
        #[arg(long)]
        noir: bool,
    },

    /// Generate circuit inputs from a cached graph
    GenerateCircuitInput {
        /// Path to the graph JSON file
        #[arg(short, long)]
        graph_path: PathBuf,

        /// Input string to match
        #[arg(short, long)]
        input: String,

        /// Maximum haystack length
        #[arg(short = 'l', long)]
        max_haystack_len: usize,

        /// Maximum match length
        #[arg(short = 'm', long)]
        max_match_len: usize,

        /// Output JSON file for circuit inputs
        #[arg(short, long)]
        output: PathBuf,

        /// Generate inputs for Noir
        #[arg(short, long)]
        noir: Option<bool>
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
    file_extension: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    validate_cli_template_name(template_name)?;

    // Create output directory if it doesn't exist
    std::fs::create_dir_all(output_dir)?;

    let snake_case_name = template_name.to_snake_case();

    // Save circuit file
    let circuit_path = output_dir.join(format!("{}_regex.{}", snake_case_name, file_extension));
    std::fs::write(&circuit_path, circom_code)?;

    // Save graph JSON
    let graph_json = nfa.to_json()?;
    let graph_path = output_dir.join(format!("{}_graph.json", snake_case_name));
    std::fs::write(&graph_path, graph_json)?;

    println!("Generated files:");
    println!("  Circuit: {}", circuit_path.display());
    println!("  Graph: {}", graph_path.display());

    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Decomposed {
            decomposed_regex_path,
            output_file_path,
            template_name,
            noir,
        } => {
            let config: DecomposedRegexConfig =
                serde_json::from_reader(File::open(decomposed_regex_path)?)?;

            let (combined_pattern, max_bytes) = decomposed_to_composed_regex(&config);

            let nfa = compile(&combined_pattern)?;
            let max_bytes = match max_bytes.is_empty() {
                true => None,
                false => Some(&max_bytes[..]),
            };
            let code = match noir {
                true => nfa.generate_noir_code(&combined_pattern, max_bytes)?,
                false => nfa.generate_circom_code(&template_name, &combined_pattern, max_bytes)?,
            };

            let file_extension = if noir { "nr" } else { "circom" };
            save_outputs(
                &nfa,
                code,
                &output_file_path,
                &template_name,
                &file_extension,
            )?;
        }

        Commands::Raw {
            raw_regex,
            output_file_path,
            template_name,
            noir,
        } => {
            let nfa = compile(&raw_regex)?;
            let code = if noir {
                nfa.generate_noir_code(&raw_regex, None)?
            } else {
                nfa.generate_circom_code(&template_name, &raw_regex, None)?
            };

            // Create output file path by combining directory and template name
            let file_extension = if noir { ".nr" } else { ".circom" };
            save_outputs(
                &nfa,
                code,
                &output_file_path,
                &template_name,
                &file_extension,
            )?;
        }

        Commands::GenerateCircuitInput {
            graph_path,
            input,
            max_haystack_len,
            max_match_len,
            output,
            noir
        } => {
            // Load the cached graph
            let graph_json = std::fs::read_to_string(graph_path)?;
            let nfa = NFAGraph::from_json(&graph_json)?;

            // Generate circuit inputs
            let inputs = nfa.generate_circuit_inputs(&input, max_haystack_len, max_match_len)?;

            // Save inputs
            if noir.is_none_or(|x| !x ) {
                let input_json = serde_json::to_string_pretty(&inputs)?;
                std::fs::write(&output, input_json)?;
            } else {
                let input_toml = NFAGraph::to_prover_toml(&inputs);
                std::fs::write(&output, input_toml)?;
            }

            println!("Generated circuit inputs: {}", output.display());
        }
    }

    Ok(())
}
