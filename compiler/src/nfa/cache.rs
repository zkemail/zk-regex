use serde_json::{Value, json};
use std::fs;
use std::path::Path;

use crate::error::Error;

use super::NFAGraph;

impl NFAGraph {
    pub fn save_to_file<P: AsRef<Path>>(&self, path: P) -> Result<(), Error> {
        let json = json!({
            "nodes": self.nodes,
            "start_states": self.start_states,
            "accept_states": self.accept_states
        });

        fs::write(path, json.to_string()).map_err(|e| Error::SerializeError(e.to_string()))
    }

    pub fn load_from_file<P: AsRef<Path>>(path: P) -> Result<Self, Error> {
        let contents =
            fs::read_to_string(path).map_err(|e| Error::DeserializeError(e.to_string()))?;

        serde_json::from_str(&contents).map_err(|e| Error::DeserializeError(e.to_string()))
    }
}
