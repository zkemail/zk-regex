import circom_tester from "circom_tester";
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import apis from "../../apis/pkg";
import compiler from "../../compiler/pkg";
const option = {
  include: path.join(__dirname, "../../../node_modules"),
};
const wasm_tester = circom_tester.wasm;

jest.setTimeout(120000);
describe("Simple Regex Decomposed", () => {
  let circuit;
  beforeAll(async () => {
    const email_addr_json = readFileSync(
      path.join(__dirname, "./circuits/simple_regex_decomposed.json"),
      "utf8"
    );
    const circom = compiler.genFromDecomposed(
      email_addr_json,
      "SimpleRegexDecomposed"
    );
    writeFileSync(
      path.join(__dirname, "./circuits/simple_regex_decomposed.circom"),
      circom
    );
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
