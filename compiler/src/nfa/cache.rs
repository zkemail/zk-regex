use super::{NFAGraph, NFAResult, error::NFAError};

impl NFAGraph {
    /// Serialize the graph to JSON string
    pub fn to_json(&self) -> NFAResult<String> {
        let serialized = NFAGraph {
            regex: self.regex.clone(),
            nodes: self.nodes.clone(),
            start_states: self.start_states.clone(),
            accept_states: self.accept_states.clone(),
        };

        serde_json::to_string(&serialized).map_err(|e| NFAError::Serialization(e.to_string()))
    }

    /// Create graph from JSON string
    pub fn from_json(json: &str) -> NFAResult<Self> {
        let serialized: NFAGraph =
            serde_json::from_str(json).map_err(|e| NFAError::Serialization(e.to_string()))?;

        // Verify the loaded graph
        let graph = Self {
            regex: serialized.regex,
            nodes: serialized.nodes,
            start_states: serialized.start_states,
            accept_states: serialized.accept_states,
        };
        graph.verify()?;

        Ok(graph)
    }
}
