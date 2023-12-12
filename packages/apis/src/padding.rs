use neon::prelude::*;

pub fn pad_string(str: &str, padded_bytes_size: usize) -> Vec<u8> {
    let mut padded_bytes = str.as_bytes().to_vec();
    padded_bytes.append(&mut vec![0; padded_bytes_size - padded_bytes.len()]);
    padded_bytes
}

pub fn pad_string_node(mut cx: FunctionContext) -> JsResult<JsArray> {
    let string = cx.argument::<JsString>(0)?.value(&mut cx);
    let padded_bytes_size = cx.argument::<JsNumber>(1)?.value(&mut cx) as usize;
    let padded_bytes = pad_string(&string, padded_bytes_size);
    let padded_array = JsArray::new(&mut cx, padded_bytes_size as u32);
    for (idx, byte) in padded_bytes.into_iter().enumerate() {
        let js_byte = cx.number(byte);
        padded_array.set(&mut cx, idx as u32, js_byte)?;
    }
    Ok(padded_array)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pad_string_valid() {
        let str = "Hello, World!";
        let padded_bytes_size = 20;
        let padded_bytes = pad_string(str, padded_bytes_size);
        assert_eq!(padded_bytes.len(), padded_bytes_size);
        assert_eq!(&padded_bytes[0..str.len()], str.as_bytes());
        for byte in &padded_bytes[str.len()..] {
            assert_eq!(*byte, 0);
        }
    }

    #[test]
    fn test_pad_string_empty_string() {
        let str = "";
        let padded_bytes_size = 10;
        let padded_bytes = pad_string(str, padded_bytes_size);
        assert_eq!(padded_bytes.len(), padded_bytes_size);
    }

    #[test]
    fn test_pad_string_empty_string_no_padding() {
        let str = "";
        let padded_bytes_size = 0;
        let padded_bytes = pad_string(str, padded_bytes_size);
        assert_eq!(padded_bytes.len(), padded_bytes_size);
    }
}