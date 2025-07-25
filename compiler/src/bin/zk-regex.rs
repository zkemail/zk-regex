use clap::{Parser, Subcommand};
use std::{fs::File, path::PathBuf, str::FromStr};
use zk_regex_compiler::{
    CompilerError, DecomposedRegexConfig, NFAGraph, ProvingFramework, gen_circuit_inputs,
    gen_from_decomposed, gen_from_raw, save_outputs, validate_cli_template_name,
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

            match gen_from_decomposed(config, &template_name, proving_framework) {
                Ok((nfa, code)) => {
                    save_outputs(
                        &nfa,
                        code,
                        &output_file_path,
                        &template_name,
                        &proving_framework.file_extension(),
                    )?;
                }
                Err(compiler_err) => {
                    eprintln!("\n❌ Compilation failed:");
                    eprintln!("Error Code: {}", compiler_err.code());
                    eprintln!("Message: {}", compiler_err.user_message());

                    if compiler_err.is_recoverable() {
                        eprintln!("\n💡 This error can be fixed by adjusting your input.");
                    } else {
                        eprintln!("\n⚠️  This appears to be an internal compiler issue.");
                        eprintln!("Please consider reporting this issue if it persists.");
                    }

                    std::process::exit(1);
                }
            }
        }

        Commands::Raw {
            raw_regex,
            output_file_path,
            template_name,
            proving_framework,
        } => {
            let proving_framework = ProvingFramework::from_str(&proving_framework)?;

            match gen_from_raw(&raw_regex, None, &template_name, proving_framework) {
                Ok((nfa, code)) => {
                    save_outputs(
                        &nfa,
                        code,
                        &output_file_path,
                        &template_name,
                        &proving_framework.file_extension(),
                    )?;
                }
                Err(compiler_err) => {
                    eprintln!("\n❌ Compilation failed:");
                    eprintln!("Error Code: {}", compiler_err.code());
                    eprintln!("Message: {}", compiler_err.user_message());

                    if compiler_err.is_recoverable() {
                        eprintln!("\n💡 This error can be fixed by adjusting your input.");
                    } else {
                        eprintln!("\n⚠️  This appears to be an internal compiler issue.");
                        eprintln!("Please consider reporting this issue if it persists.");
                    }

                    std::process::exit(1);
                }
            }
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

            match NFAGraph::from_json(&graph_json) {
                Ok(nfa) => {
                    // Generate circuit inputs
                    let framework = match proving_framework.as_str() {
                        "circom" => ProvingFramework::Circom,
                        "noir" => ProvingFramework::Noir,
                        _ => {
                            eprintln!("❌ Invalid proving framework: {}", proving_framework);
                            eprintln!("Supported frameworks: circom, noir");
                            std::process::exit(1);
                        }
                    };

                    match gen_circuit_inputs(
                        &nfa,
                        &input,
                        max_haystack_len,
                        max_match_len,
                        framework,
                    ) {
                        Ok(inputs) => {
                            let input_json = serde_json::to_string_pretty(&inputs)?;
                            std::fs::write(&output_file_path, input_json)?;
                            println!(
                                "✅ Generated circuit inputs: {}",
                                output_file_path.display()
                            );
                        }
                        Err(compiler_err) => {
                            eprintln!("\n❌ Input generation failed:");
                            eprintln!("Error Code: {}", compiler_err.code());
                            eprintln!("Message: {}", compiler_err.user_message());

                            if compiler_err.is_recoverable() {
                                eprintln!(
                                    "\n💡 This error can be fixed by adjusting your input or parameters."
                                );
                            }

                            std::process::exit(1);
                        }
                    }
                }
                Err(nfa_err) => {
                    let compiler_err = CompilerError::from(nfa_err);
                    eprintln!("\n❌ Failed to load NFA graph:");
                    eprintln!("Error Code: {}", compiler_err.code());
                    eprintln!("Message: {}", compiler_err.user_message());
                    std::process::exit(1);
                }
            }
        }
    }

    Ok(())
}
