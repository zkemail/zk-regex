use thiserror::Error;

#[derive(Error, Debug)]
pub enum CompilerError {
    #[error("Failed to open file: {0}")]
    FileOpenError(#[from] std::io::Error),
    #[error("Failed to parse JSON: {0}")]
    JsonParseError(#[from] serde_json::Error),
    #[error("{0}")]
    GenericError(String),
    #[error(
        "Failed to build DFA for regex: \"{regex}\", please check your regex. Error: {source}"
    )]
    BuildError {
        regex: String,
        #[source]
        source: regex_automata::dfa::dense::BuildError,
    },
    #[error("Error in Regex: {0}")]
    RegexError(#[from] regex::Error),
    #[error("Parse Error: {0}")]
    ParseError(String),
    #[error("Graph Error: {0}")]
    GraphError(String),
    #[error("No accepted state found in DFA")]
    NoAcceptedState,
    #[error("Accept Nodes Error: {0}")]
    AcceptNodesError(String),
}
