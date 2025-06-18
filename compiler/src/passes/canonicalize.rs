//! State canonicalization pass

use super::NFAResult;
use crate::ir::NFAGraph;

impl NFAGraph {
    /// Canonicalize state numbering and transition ordering
    pub fn canonicalize(&mut self) -> NFAResult<()> {
        // TODO: Implement canonicalization
        Ok(())
    }
}
