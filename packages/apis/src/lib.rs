use neon::prelude::*;
pub mod extract_substrs;
pub mod padding;
use extract_substrs::extract_substr_idxes_node;
use padding::pad_string_node;

#[cfg(feature = "export_neon_main")]
#[neon::main]
fn main(mut cx: ModuleContext) -> NeonResult<()> {
    cx.export_function("extractSubstrIdxes", extract_substr_idxes_node)?;
    cx.export_function("padString", pad_string_node)?;
    Ok(())
}
