use crate::gen_from_decomposed;
use neon::prelude::*;

pub(crate) fn gen_from_decomposed_node(mut cx: FunctionContext) -> JsResult<JsNull> {
    let decomposed_regex_path = cx.argument::<JsString>(0)?.value(&mut cx);
    let halo2_dir_path = cx.argument_opt(1).map(|v| {
        v.to_string(&mut cx)
            .expect("halo2_dir_path must be null or string")
            .value(&mut cx)
    });
    let circom_file_path = cx.argument_opt(2).map(|v| {
        v.to_string(&mut cx)
            .expect("circom_file_path must be null or string")
            .value(&mut cx)
    });
    let circom_template_name = cx.argument_opt(3).map(|v| {
        v.to_string(&mut cx)
            .expect("circom_template_name must be null or string")
            .value(&mut cx)
    });
    let gen_substrs = cx.argument_opt(4).map(|v| {
        v.as_value(&mut cx)
            .downcast::<JsBoolean, _>(&mut cx)
            .expect("gen_substrs must be null or boolean")
            .value(&mut cx)
    });
    gen_from_decomposed(
        &decomposed_regex_path,
        halo2_dir_path.as_ref().map(|s| s.as_str()),
        circom_file_path.as_ref().map(|s| s.as_str()),
        circom_template_name.as_ref().map(|s| s.as_str()),
        gen_substrs,
    );
    Ok(cx.null())
}
