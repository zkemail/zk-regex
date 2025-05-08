use clap::{Parser, Subcommand};
use std::{fs::File, path::PathBuf, str::FromStr};
use zk_regex_compiler::{
    DecomposedRegexConfig, NFAGraph, ProvingFramework, gen_from_decomposed, gen_from_raw,
    generate_circuit_inputs, save_outputs, validate_cli_template_name,
};

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

        /// Proving framework to use (e.g., circom, noir)
        #[arg(short, long)]
        proving_framework: String,
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

        /// Proving framework to use (e.g., circom, noir)
        #[arg(short, long)]
        proving_framework: String,
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
        output_file_path: PathBuf,

        /// Proving framework to use (e.g., circom, noir)
        #[arg(short, long)]
        proving_framework: String,
    },
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Decomposed {
            decomposed_regex_path,
            output_file_path,
            template_name,
            proving_framework,
        } => {
            let config: DecomposedRegexConfig =
                serde_json::from_reader(File::open(decomposed_regex_path)?)?;
            let proving_framework = ProvingFramework::from_str(&proving_framework)?;
            let (nfa, code) = gen_from_decomposed(config, &template_name, proving_framework)?;
            save_outputs(
                &nfa,
                code,
                &output_file_path,
                &template_name,
                &proving_framework.file_extension(),
            )?;
        }

        Commands::Raw {
            raw_regex,
            output_file_path,
            template_name,
            proving_framework,
        } => {
            let proving_framework = ProvingFramework::from_str(&proving_framework)?;
            let (nfa, code) = gen_from_raw(&raw_regex, None, &template_name, proving_framework)?;
            save_outputs(
                &nfa,
                code,
                &output_file_path,
                &template_name,
                &proving_framework.file_extension(),
            )?;
        }

        Commands::GenerateCircuitInput {
            graph_path,
            input,
            max_haystack_len,
            max_match_len,
            output_file_path,
            proving_framework,
        } => {
            // Load the cached graph
            let graph_json = std::fs::read_to_string(graph_path)?;
            let nfa = NFAGraph::from_json(&graph_json)?;

            // Generate circuit inputs
            let inputs = match proving_framework.as_str() {
                "circom" => generate_circuit_inputs(
                    &nfa,
                    &input,
                    max_haystack_len,
                    max_match_len,
                    ProvingFramework::Circom,
                )?,
                "noir" => generate_circuit_inputs(
                    &nfa,
                    &input,
                    max_haystack_len,
                    max_match_len,
                    ProvingFramework::Noir,
                )?,
                _ => {
                    return Err("Invalid proving framework".into());
                }
            };

            // Save inputs
            let input_json = serde_json::to_string_pretty(&inputs)?;
            std::fs::write(&output_file_path, input_json)?;

            println!("Generated circuit inputs: {}", output_file_path.display());
        }
    }

    Ok(())
}
