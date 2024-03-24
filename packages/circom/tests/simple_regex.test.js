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
describe("Simple Regex", () => {
  let circuit;
  beforeAll(async () => {
    const substrs_json = readFileSync(
      path.join(__dirname, "./circuits/simple_regex_substrs.json"),
      "utf8"
    );
    const circom = compiler.genFromRaw(
      "1=(a|b) (2=(b|c)+ )+d",
      substrs_json,
      "SimpleRegex"
    );
    writeFileSync(
      path.join(__dirname, "./circuits/simple_regex.circom"),
      circom
    );
    circuit = await wasm_tester(
      path.join(__dirname, "./circuits/test_simple_regex.circom"),
      option
    );
  });

  it("case 1", async () => {
    const input = "1=a 2=b d";
    const paddedStr = apis.padString(input, 64);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [[2], [6], [8]];
    for (let substr_idx = 0; substr_idx < 3; ++substr_idx) {
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

  it("case 2", async () => {
    const input = "1=a 2=b 2=bc 2=c d";
    const paddedStr = apis.padString(input, 64);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [[2], [6, 10, 11, 15], [17]];
    for (let substr_idx = 0; substr_idx < 3; ++substr_idx) {
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

  it("case 3", async () => {
    const input = "1=a 2=b 2=bc 2=c da 1=a 2=cb 2=c 2=b dd";
    const paddedStr = apis.padString(input, 64);
    const circuitInputs = {
      msg: paddedStr,
    };

    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const revealedIdx = [
      [2, 22],
      [6, 10, 11, 15, 26, 27, 31, 35],
      [17, 37],
    ];
    for (let substr_idx = 0; substr_idx < 3; ++substr_idx) {
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
