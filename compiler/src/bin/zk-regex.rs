use clap::{Parser, Subcommand};
use compiler::compile;
use serde::Deserialize;
use std::{fs::File, path::PathBuf};

#[derive(Deserialize)]
enum RegexPart {
    Pattern(String),
    PublicPattern((String, usize)), // (pattern, max_substring_bytes)
}

#[derive(Deserialize)]
struct DecomposedRegexConfig {
    parts: Vec<RegexPart>,
}

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

        /// File path for circuit output
        #[arg(short, long)]
        output_file_path: PathBuf,

        /// Template name
        #[arg(short, long, default_value = "Regex")]
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

        /// File path for Circom output
        #[arg(short, long)]
        output_file_path: PathBuf,

        /// Template name
        #[arg(short, long, default_value = "Regex")]
        template_name: String,

        /// Noir boolean
        #[arg(long)]
        noir: bool,
    },
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

            // Build combined pattern and collect max_bytes for public parts
            let mut combined_parts = Vec::new();
            let mut max_bytes = Vec::new();

            for part in &config.parts {
                match part {
                    RegexPart::Pattern(pattern) => {
                        combined_parts.push(pattern.clone());
                    }
                    RegexPart::PublicPattern((pattern, max_len)) => {
                        combined_parts.push(format!("({})", pattern));
                        max_bytes.push(*max_len);
                    }
                }
            }

            let combined_pattern = combined_parts.join("");
            let nfa = compile(&combined_pattern)?;

            // Generate Circom code
            let max_substring_bytes = if !max_bytes.is_empty() {
                Some(max_bytes.as_slice())
            } else {
                None
            };
            let code = if noir {
                nfa.generate_noir_code(&template_name, &combined_pattern, max_substring_bytes)?
            } else {
                nfa.generate_circom_code(&template_name, &combined_pattern, max_substring_bytes)?
            };

            // Create output file path by combining directory and template name
            let file_extension = if noir { ".nr" } else { ".circom" };
            let output_file = output_file_path.join(format!("{template_name}.{file_extension}"));
            std::fs::write(output_file, code)?;
        }

        Commands::Raw {
            raw_regex,
            output_file_path,
            template_name,
            noir,
        } => {
            let nfa = compile(&raw_regex)?;
            let code = if noir {
                nfa.generate_noir_code(&template_name, &raw_regex, None)?
            } else {
                nfa.generate_circom_code(&template_name, &raw_regex, None)?
            };

            // Create output file path by combining directory and template name
            let file_extension = if noir { ".nr" } else { ".circom" };
            let output_file = output_file_path.join(format!("{template_name}.{file_extension}"));
            std::fs::write(output_file, code)?;
        }
    }

    Ok(())
}
