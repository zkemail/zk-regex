use std::str::FromStr;

use serde::{Deserialize, Serialize};
use wasm_bindgen::prelude::*;

use crate::{circom::CircomInputs, noir::NoirInputs};

#[derive(Deserialize)]
pub enum RegexPart {
    Pattern(String),
    PublicPattern((String, usize)), // (pattern, max_substring_bytes)
}

#[derive(Deserialize)]
pub struct DecomposedRegexConfig {
    pub parts: Vec<RegexPart>,
}

/// Supported proving systems
#[wasm_bindgen]
#[derive(Serialize, Deserialize, Debug, Clone, Copy)]
#[serde(rename_all = "camelCase")]
pub enum ProvingFramework {
    Circom,
    Noir,
    // Future systems:
    // Halo2,
}

/// Input types for different proving systems
#[derive(Serialize)]
#[serde(tag = "type")]
pub enum ProverInputs {
    #[serde(rename = "circom")]
    Circom(CircomInputs),
    #[serde(rename = "noir")]
    Noir(NoirInputs),
}

/// Output from regex compilation
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegexOutput {
    pub graph: String,
    pub code: String,
}

impl FromStr for ProvingFramework {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(match s {
            "circom" => Self::Circom,
            "noir" => Self::Noir,
            _ => {
                return Err(format!("Invalid proving framework: {}", s));
            }
        })
    }
}

impl ProvingFramework {
    pub fn file_extension(&self) -> &str {
        match self {
            Self::Circom => "circom",
            Self::Noir => "nr",
        }
    }
}
