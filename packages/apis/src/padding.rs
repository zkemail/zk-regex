use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn pad_string(str: &str, padded_bytes_size: usize) -> Vec<u8> {
    let mut padded_bytes = str.as_bytes().to_vec();
    padded_bytes.append(&mut vec![0; padded_bytes_size - padded_bytes.len()]);
    padded_bytes
}
