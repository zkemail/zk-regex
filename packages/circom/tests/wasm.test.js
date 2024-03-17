const wasm = require("../../compiler/wasmpack_nodejs/zk_regex_compiler");

const jsonData = `{
    "transitions": [
      [[2, 3]],
      [
        [6, 7],
        [7, 7]
      ],
      [[8, 9]]
    ]
  }`;

test('test gen_from_raw_memory', () => {
    expect(wasm.gen_from_raw_memory('1=(a|b) (2=(b|c)+ )+d', jsonData, 'TestTemplate')).toBe('');
});
