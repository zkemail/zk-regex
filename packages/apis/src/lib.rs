use neon::prelude::*;
pub mod extract_substrs;
pub mod padding;
use extract_substrs::*;
use padding::pad_string_node;

#[cfg(feature = "export_neon_main")]
#[neon::main]
fn main(mut cx: ModuleContext) -> NeonResult<()> {
    cx.export_function("extractSubstrIdxes", extract_substr_idxes_node)?;
    cx.export_function("padString", pad_string_node)?;
    cx.export_function("extractEmailAddrIdxes", extract_email_addr_idxes_node)?;
    cx.export_function("extractEmailDomainIdxes", extract_email_domain_idxes_node)?;
    cx.export_function(
        "extractEmailAddrWithNameIdxes",
        extract_email_addr_with_name_idxes_node,
    )?;
    cx.export_function("extractFromAllIdxes", extract_from_all_idxes_node)?;
    cx.export_function("extractFromAddrIdxes", extract_from_addr_idxes_node)?;
    cx.export_function("extractToAllIdxes", extract_to_all_idxes_node)?;
    cx.export_function("extractToAddrIdxes", extract_to_addr_idxes_node)?;
    cx.export_function("extractSubjectAllIdxes", extract_subject_all_idxes_node)?;
    cx.export_function("extractBodyHashIdxes", extract_body_hash_idxes_node)?;
    cx.export_function("extractTimestampIdxes", extract_timestamp_idxes_node)?;
    cx.export_function("extractMessageIdIdxes", extract_message_id_idxes_node)?;
    Ok(())
}
