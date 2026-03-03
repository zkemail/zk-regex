//! Intermediate Representation module
//!
//! This module contains the core data structures used throughout the compilation pipeline.
//!
//! The compilation flow is:
//! 1. Parse regex with `regex-automata` -> Thompson NFA
//! 2. Convert to `IntermediateNFA` (may have epsilon transitions)
//! 3. Process and optimize intermediate representation
//! 4. Convert to final `NFAGraph` (no epsilon transitions, circuit-ready)

pub mod graph;
pub mod intermediate;
pub mod nfa;

pub use graph::*;
pub use intermediate::*;
pub use nfa::*;
