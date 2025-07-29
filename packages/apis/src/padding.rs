/// Pads a string to a specified byte size with null bytes.
///
/// # Arguments
///
/// * `str` - The input string to pad.
/// * `padded_bytes_size` - The target size in bytes after padding.
///
/// # Returns
///
/// A Vec<u8> containing the padded bytes.
///
/// # Performance Notes
///
/// This function is optimized for large strings by pre-allocating the exact
/// capacity needed and avoiding unnecessary memory operations.
pub fn pad_string(str: &str, padded_bytes_size: usize) -> Vec<u8> {
    let str_bytes = str.as_bytes();
    let str_len = str_bytes.len();
    
    if padded_bytes_size <= str_len {
        // No padding needed or string is already larger
        return str_bytes.to_vec();
    }
    
    // Pre-allocate exact capacity to avoid reallocations
    let mut padded_bytes = Vec::with_capacity(padded_bytes_size);
    
    // Copy original string bytes
    padded_bytes.extend_from_slice(str_bytes);
    
    // Add padding zeros efficiently
    let padding_size = padded_bytes_size - str_len;
    padded_bytes.resize(padded_bytes_size, 0);
    
    padded_bytes
}
