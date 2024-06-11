use clap::{Parser, Subcommand};

use zk_regex_compiler::*;

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
        #[arg(short, long)]
        circom_file_path: Option<String>,
        #[arg(short, long)]
        template_name: Option<String>,
        #[arg(short, long)]
        gen_substrs: Option<bool>,
    },
    Raw {
        #[arg(short, long)]
        raw_regex: String,
        #[arg(short, long)]
        substrs_json_path: Option<String>,
        #[arg(short, long)]
        circom_file_path: Option<String>,
        #[arg(short, long)]
        template_name: Option<String>,
        #[arg(short, long)]
        gen_substrs: Option<bool>,
    },
}

fn main() {
    let cli = Cli::parse();
    match cli.command {
        Commands::Decomposed {
            decomposed_regex_path,
            circom_file_path,
            template_name,
            gen_substrs,
        } => {
            gen_from_decomposed(
                &decomposed_regex_path,
                circom_file_path.as_ref().map(|s| s.as_str()),
                template_name.as_ref().map(|s| s.as_str()),
                gen_substrs,
            );
        }
        Commands::Raw {
            raw_regex,
            substrs_json_path,
            circom_file_path,
            template_name,
            gen_substrs,
        } => {
            gen_from_raw(
                &raw_regex,
                substrs_json_path.as_ref().map(|s| s.as_str()),
                circom_file_path.as_ref().map(|s| s.as_str()),
                template_name.as_ref().map(|s| s.as_str()),
                gen_substrs,
            );
        }
    }
}
