const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;
import * as path from "path";
import fs from 'fs'
const apis = require("../../apis");
const wasm = require("../../compiler/wasmpack_nodejs/zk_regex_compiler");
const option = {
  include: path.join(__dirname, "../../../node_modules"),
};

jest.setTimeout(120000);
describe("Simple Regex Decomposed", () => {
  let circuit;
  beforeAll(async () => {
    const email_addr_json = fs.readFileSync(path.join(__dirname, "./circuits/simple_regex_decomposed.json"), "utf8")
    const circom = wasm.gen_from_decomposed_memory(email_addr_json, 'SimpleRegexDecomposed');
    fs.writeFileSync(path.join(__dirname, "./circuits/simple_regex_decomposed.circom"), circom);
    circuit = await wasm_tester(
      path.join(__dirname, "./circuits/test_simple_regex_decomposed.circom"),
      option
    );
  });

  it("case 1", async () => {
    const input = "email was meant for @zkRegex.";
    const paddedStr = apis.padString(input, 64);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [[21, 22, 23, 24, 25, 26, 27]];
    for (let substr_idx = 0; substr_idx < 1; ++substr_idx) {
      for (let idx = 0; idx < 64; ++idx) {
        if (revealedIdx[substr_idx].includes(idx)) {
          expect(BigInt(paddedStr[idx])).toEqual(
            witness[2 + 64 * substr_idx + idx]
          );
        } else {
          expect(0n).toEqual(witness[2 + 64 * substr_idx + idx]);
        }
      }
    }
  });
});
