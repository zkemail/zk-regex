//! ZK Regex Compiler CLI
//!
//! This binary provides a command-line interface for the ZK Regex Compiler.
//! It supports two main commands: `Decomposed` for working with decomposed regex files,
//! and `Raw` for working with raw regex strings.
//!
//! # Usage
//!
//! ## Decomposed Command
//! Process a decomposed regex file:
//!
//! ```
//! zk-regex decomposed --decomposed-regex-path <PATH> [OPTIONS]
//! ```
//!
//! Options:
//! - `-d, --decomposed-regex-path <PATH>`: Path to the decomposed regex JSON file (required)
//! - `-h, --halo2-dir-path <PATH>`: Directory path for Halo2 output
//! - `-c, --circom-file-path <PATH>`: File path for Circom output
//! - `-t, --template-name <NAME>`: Template name
//! - `-g, --gen-substrs`: Generate substrings
//!
//! Example:
//! ```
//! zk-regex decomposed -d regex.json -h ./halo2_output -c ./circom_output.circom -t MyTemplate -g true
//! ```
//!
//! ## Raw Command
//! Process a raw regex string:
//!
//! ```
//! zk-regex raw --raw-regex <REGEX> [OPTIONS]
//! ```
//!
//! Options:
//! - `-r, --raw-regex <REGEX>`: Raw regex string (required)
//! - `-s, --substrs-json-path <PATH>`: Path to substrings JSON file
//! - `-h, --halo2-dir-path <PATH>`: Directory path for Halo2 output
//! - `-c, --circom-file-path <PATH>`: File path for Circom output
//! - `-t, --template-name <NAME>`: Template name
//! - `-g, --gen-substrs`: Generate substrings
//!
//! Example:
//! ```
//! zk-regex raw -r "a*b+c?" -s substrings.json -h ./halo2_output -c ./circom_output.circom -t MyTemplate -g true
//! ```

use clap::{Parser, Subcommand};
use zk_regex_compiler::{gen_from_decomposed, gen_from_raw};

#[derive(Parser, Debug, Clone)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Debug, Subcommand, Clone)]
enum Commands {
    Decomposed {
        #[arg(short, long)]
        decomposed_regex_path: String,
        #[arg(long)]
        halo2_dir_path: Option<String>,
        #[arg(short, long)]
        circom_file_path: Option<String>,
        #[arg(short, long)]
        template_name: Option<String>,
        #[arg(long)]
        noir_file_path: Option<String>,
        #[arg(short, long)]
        gen_substrs: Option<bool>,
    },
    Raw {
        #[arg(short, long)]
        raw_regex: String,
        #[arg(short, long)]
        substrs_json_path: Option<String>,
        #[arg(long)]
        halo2_dir_path: Option<String>,
        #[arg(short, long)]
        circom_file_path: Option<String>,
        #[arg(short, long)]
        template_name: Option<String>,
        #[arg(long)]
        noir_file_path: Option<String>,
        #[arg(short, long)]
        gen_substrs: Option<bool>,
    },
}

fn main() {
    let cli = Cli::parse();
    match cli.command {
        Commands::Decomposed { .. } => process_decomposed(cli),
        Commands::Raw { .. } => process_raw(cli),
    }
}

fn process_decomposed(cli: Cli) {
    if let Commands::Decomposed {
        decomposed_regex_path,
        halo2_dir_path,
        circom_file_path,
        template_name,
        noir_file_path,
        gen_substrs,
    } = cli.command
    {
        if let Err(e) = gen_from_decomposed(
            &decomposed_regex_path,
            halo2_dir_path.as_deref(),
            circom_file_path.as_deref(),
            template_name.as_deref(),
            noir_file_path.as_deref(),
            gen_substrs,
        ) {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
    }
}

fn process_raw(cli: Cli) {
    if let Commands::Raw {
        raw_regex,
        substrs_json_path,
        halo2_dir_path,
        circom_file_path,
        template_name,
        noir_file_path,
        gen_substrs,
    } = cli.command
    {
        if let Err(e) = gen_from_raw(
            &raw_regex,
            substrs_json_path.as_deref(),
            halo2_dir_path.as_deref(),
            circom_file_path.as_deref(),
            template_name.as_deref(),
            noir_file_path.as_deref(),
            gen_substrs,
        ) {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
    }
}
