use crate::{gen_from_decomposed, gen_from_raw};
use neon::context::Context;
use neon::prelude::*;

pub(crate) fn gen_from_decomposed_node(mut cx: FunctionContext) -> JsResult<JsNull> {
    println!("Starting gen_from_decomposed_node function");
    let decomposed_regex_path = cx.argument::<JsString>(0)?.value(&mut cx);
    println!("Decomposed regex path: {}", decomposed_regex_path);
    let obj = cx.argument::<JsObject>(1)?;
    println!("Object: {:?}", obj);

    let circom_file_path = obj
        .get_opt::<JsString, _, _>(&mut cx, "circomFilePath")?
        .map(|v| {
            let path = v.to_string(&mut cx)
                .expect("circomFilePath must be null or string")
                .value(&mut cx);
            println!("Circom file path: {}", path);
            path
        });
    let circom_template_name = obj
        .get_opt::<JsString, _, _>(&mut cx, "templateName")?
        .map(|v| {
            let name = v.to_string(&mut cx)
                .expect("templateName must be null or string")
                .value(&mut cx);
            println!("Circom template name: {}", name);
            name
        });
    let gen_substrs = obj
        .get_opt::<JsBoolean, _, _>(&mut cx, "genSubstrs")?
        .map(|v| {
            let gen = v.as_value(&mut cx)
                .downcast::<JsBoolean, _>(&mut cx)
                .expect("genSubstrs must be null or boolean")
                .value(&mut cx);
            println!("Gen substrs: {}", gen);
            gen
        });
    println!("Calling gen_from_decomposed function");
    gen_from_decomposed(
        &decomposed_regex_path,
        circom_file_path.as_ref().map(|s| s.as_str()),
        circom_template_name.as_ref().map(|s| s.as_str()),
        gen_substrs,
    );
    println!("Finished gen_from_decomposed_node function");
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
    let template_name = obj
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
        template_name.as_ref().map(|s| s.as_str()),
        gen_substrs,
    );
    Ok(cx.null())
}
