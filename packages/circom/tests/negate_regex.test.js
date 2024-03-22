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
describe("Negate Regex", () => {
  let circuit;
  beforeAll(async () => {
    const email_addr_json = readFileSync(
      path.join(__dirname, "./circuits/negate1.json"),
      "utf8"
    );
    const circom = compiler.gen_from_decomposed_memory(
      email_addr_json,
      "Negate1Regex"
    );
    writeFileSync(
      path.join(__dirname, "./circuits/negate1_regex.circom"),
      circom
    );
    circuit = await wasm_tester(
      path.join(__dirname, "./circuits/test_negate1_regex.circom"),
      option
    );
  });

  it("case 1 with regex 1", async () => {
    const input = "a: ABCDEFG XYZ.";
    const paddedStr = apis.pad_string(input, 64);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]];
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

  it("case 2 with regex 1", async () => {
    const input = "a: CRIPTOGRAFíA.";
    const paddedStr = apis.pad_string(input, 64);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]];
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

  it("case 3 with regex 1", async () => {
    const input = "a: あいう.";
    const paddedStr = apis.pad_string(input, 64);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [[2, 3, 4, 5, 6, 7, 8, 9, 10, 11]];
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

  it("case 4 with regex 1", async () => {
    const input = "a: التشفير.";
    const paddedStr = apis.pad_string(input, 64);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]];
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
