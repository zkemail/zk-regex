//! Intermediate Representation module
//!
//! This module contains the core data structures used throughout the compilation pipeline.

pub mod graph;
pub mod nfa;

pub use graph::*;
pub use nfa::*;
