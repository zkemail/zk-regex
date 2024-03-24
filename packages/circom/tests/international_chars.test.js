import circom_tester from "circom_tester";
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import apis from "../../apis/pkg";
import compiler from "../../compiler/pkg";
const option = {
  include: path.join(__dirname, "../../../node_modules"),
};
const wasm_tester = circom_tester.wasm;

jest.setTimeout(300000);
describe("Simple Regex Decomposed", () => {
  let circuit;
  beforeAll(async () => {
    const email_addr_json = readFileSync(
      path.join(__dirname, "./circuits/international_chars_decomposed.json"),
      "utf8"
    );
    const circom = compiler.genFromDecomposed(
      email_addr_json,
      "InternationalCharsDecomposed"
    );
    writeFileSync(
      path.join(__dirname, "./circuits/international_chars_decomposed.circom"),
      circom
    );
    circuit = await wasm_tester(
      path.join(
        __dirname,
        "./circuits/test_international_chars_decomposed.circom"
      ),
      option
    );
  });

  it("case 1", async () => {
    const input =
      "Latin-Extension=Ʃƣƙ Greek=ϕω Cyrillic=иЩ Arabic=أبت Devanagari=आदित्य Hiragana&Katakana=なツ";
    const paddedStr = apis.padString(input, 128);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [
      [16, 17, 18, 19, 20, 21],
      [29, 30, 31, 32],
      [43, 44, 45, 46],
      [55, 56, 57, 58, 59, 60, 61, 62],
      [75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92],
      [112, 113, 114, 115, 116, 117],
    ];
    for (let substr_idx = 0; substr_idx < 6; ++substr_idx) {
      for (let idx = 0; idx < 128; ++idx) {
        if (revealedIdx[substr_idx].includes(idx)) {
          expect(BigInt(paddedStr[idx])).toEqual(
            witness[2 + 128 * substr_idx + idx]
          );
        } else {
          expect(0n).toEqual(witness[2 + 128 * substr_idx + idx]);
        }
      }
    }
  });
});
