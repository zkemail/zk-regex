import * as wasm from "../../compiler/pkg/zk_regex_compiler";

test('test gen_from_raw_memory', () => {
    expect(wasm.gen_from_raw_memory('', '', '')).toBe('');
});
