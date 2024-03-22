use js_sys::Array;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn pad_string(str: &str, padded_bytes_size: usize) -> Array {
    let mut padded_bytes = str.as_bytes().to_vec();
    padded_bytes.append(&mut vec![0; padded_bytes_size - padded_bytes.len()]);

    let arr = Array::new_with_length(padded_bytes.len() as u32);
    for (i, byte) in padded_bytes.iter().enumerate() {
        arr.set(i as u32, JsValue::from(*byte));
    }

    arr
}
