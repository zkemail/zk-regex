mod error;
mod nfa;

use nfa::NFAGraph;

#[derive(Debug, Clone)]
pub struct Regex {
    graph: NFAGraph,
}
