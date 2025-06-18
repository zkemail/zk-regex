//! Transformation passes for the compiler pipeline
//!
//! This module contains all the transformation passes that convert
//! the input through various intermediate representations.

pub mod builder;
pub mod canonicalize;
pub mod epsilon;
mod error;
pub mod optimize;

pub use builder::*;
pub use canonicalize::*;
pub use epsilon::*;
pub use error::*;
pub use optimize::*;
