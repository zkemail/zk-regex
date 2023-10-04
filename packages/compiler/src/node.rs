use std::os::macos::raw;

use crate::{gen_from_decomposed, gen_from_raw};
use neon::prelude::*;

pub(crate) fn gen_from_decomposed_node(mut cx: FunctionContext) -> JsResult<JsNull> {
    let decomposed_regex_path = cx.argument::<JsString>(0)?.value(&mut cx);
    let obj = cx.argument::<JsObject>(1)?;

    // let halo2_dir_path = obj
    //     .get_opt::<JsString, _, _>(&mut cx, "halo2DirPath")?
    //     .map(|v| {
    //         v.to_string(&mut cx)
    //             .expect("halo2DirPath must be null or string")
    //             .value(&mut cx)
    //     });
    let circom_file_path = obj
        .get_opt::<JsString, _, _>(&mut cx, "circomFilePath")?
        .map(|v| {
            v.to_string(&mut cx)
                .expect("circomFilePath must be null or string")
                .value(&mut cx)
        });
    let circom_template_name = obj
        .get_opt::<JsString, _, _>(&mut cx, "templateName")?
        .map(|v| {
            v.to_string(&mut cx)
                .expect("templateName must be null or string")
                .value(&mut cx)
        });
    let gen_substrs = obj
        .get_opt::<JsBoolean, _, _>(&mut cx, "genSubstrs")?
        .map(|v| {
            v.as_value(&mut cx)
                .downcast::<JsBoolean, _>(&mut cx)
                .expect("genSubstrs must be null or boolean")
                .value(&mut cx)
        });
    gen_from_decomposed(
        &decomposed_regex_path,
        // halo2_dir_path.as_ref().map(|s| s.as_str()),
        circom_file_path.as_ref().map(|s| s.as_str()),
        circom_template_name.as_ref().map(|s| s.as_str()),
        gen_substrs,
    );
    Ok(cx.null())
}

pub(crate) fn gen_from_raw_node(mut cx: FunctionContext) -> JsResult<JsNull> {
    let raw_regex = cx.argument::<JsString>(0)?.value(&mut cx);
    let obj = cx.argument::<JsObject>(1)?;

    // let halo2_dir_path = obj
    //     .get_opt::<JsString, _, _>(&mut cx, "halo2DirPath")?
    //     .map(|v| {
    //         v.to_string(&mut cx)
    //             .expect("halo2DirPath must be null or string")
    //             .value(&mut cx)
    //     });
    let substrs_json_path = obj
        .get_opt::<JsString, _, _>(&mut cx, "substrsJsonPath")?
        .map(|v| {
            v.to_string(&mut cx)
                .expect("circomFilePath must be null or string")
                .value(&mut cx)
        });
    let circom_file_path = obj
        .get_opt::<JsString, _, _>(&mut cx, "circomFilePath")?
        .map(|v| {
            v.to_string(&mut cx)
                .expect("circomFilePath must be null or string")
                .value(&mut cx)
        });
    let circom_template_name = obj
        .get_opt::<JsString, _, _>(&mut cx, "templateName")?
        .map(|v| {
            v.to_string(&mut cx)
                .expect("templateName must be null or string")
                .value(&mut cx)
        });
    let gen_substrs = obj
        .get_opt::<JsBoolean, _, _>(&mut cx, "genSubstrs")?
        .map(|v| {
            v.as_value(&mut cx)
                .downcast::<JsBoolean, _>(&mut cx)
                .expect("genSubstrs must be null or boolean")
                .value(&mut cx)
        });
    gen_from_raw(
        &raw_regex,
        substrs_json_path.as_ref().map(|s| s.as_str()),
        // halo2_dir_path.as_ref().map(|s| s.as_str()),
        circom_file_path.as_ref().map(|s| s.as_str()),
        circom_template_name.as_ref().map(|s| s.as_str()),
        gen_substrs,
    );
    Ok(cx.null())
}
