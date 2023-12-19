

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
        // #[arg(short, long)]
        // halo2_dir_path: Option<String>,
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
        // #[arg(short, long)]
        // max_bytes: usize,
        #[arg(short, long)]
        substrs_json_path: Option<String>,
        // #[arg(short, long)]
        // halo2_dir_path: Option<String>,
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
            // halo2_dir_path,
            circom_file_path,
            template_name,
            gen_substrs,
        } => {
            gen_from_decomposed(
                &decomposed_regex_path,
                // halo2_dir_path.as_ref().map(|s| s.as_str()),
                circom_file_path.as_ref().map(|s| s.as_str()),
                template_name.as_ref().map(|s| s.as_str()),
                gen_substrs,
            );
        }
        Commands::Raw {
            raw_regex,
            // max_bytes,
            substrs_json_path,
            // halo2_dir_path,
            circom_file_path,
            template_name,
            gen_substrs,
        } => {
            gen_from_raw(
                &raw_regex,
                // max_bytes,
                substrs_json_path.as_ref().map(|s| s.as_str()),
                // halo2_dir_path.as_ref().map(|s| s.as_str()),
                circom_file_path.as_ref().map(|s| s.as_str()),
                template_name.as_ref().map(|s| s.as_str()),
                gen_substrs,
            );
        } // Commands::GenHalo2Texts {
          //     decomposed_regex_path,
          //     allstr_file_path,
          //     substrs_dir_path,
          // } => {
          //     let regex_decomposed: DecomposedRegexConfig =
          //         serde_json::from_reader(File::open(decomposed_regex_path).unwrap()).unwrap();
          //     let num_public_part = regex_decomposed
          //         .parts
          //         .iter()
          //         .filter(|part| part.is_public)
          //         .collect_vec()
          //         .len();
          //     let substr_file_pathes = (0..num_public_part)
          //         .map(|idx| {
          //             PathBuf::new()
          //                 .join(&substrs_dir_path)
          //                 .join(&format!("substr{}.txt", idx))
          //         })
          //         .collect_vec();
          //     regex_decomposed
          //         .gen_regex_files(
          //             &Path::new(&allstr_file_path).to_path_buf(),
          //             &substr_file_pathes,
          //         )
          //         .unwrap();
          // }
          // Commands::GenCircom {
          //     decomposed_regex_path,
          //     circom_file_path,
          //     template_name,
          // } => {
          //     let regex_decomposed: DecomposedRegexConfig =
          //         serde_json::from_reader(File::open(decomposed_regex_path).unwrap()).unwrap();
          //     let circom_path = PathBuf::from(circom_file_path);
          //     regex_decomposed
          //         .gen_circom(&circom_path, &template_name)
          //         .unwrap();
          // }
    }
}
