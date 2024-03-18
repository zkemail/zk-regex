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
describe("Subject All Regex", () => {
  let circuit;
  beforeAll(async () => {
    const email_addr_json = fs.readFileSync(path.join(__dirname, "../circuits/common/subject_all.json"), "utf8")
    const circom = wasm.gen_from_decomposed_memory(email_addr_json, 'SubjectAllRegex');
    fs.writeFileSync(path.join(__dirname, "../circuits/common/subject_all_regex.circom"), circom);
    circuit = await wasm_tester(
      path.join(__dirname, "./circuits/test_subject_all_regex.circom"),
      option
    );
  });

  it("subject from beginning", async () => {
    const subjectStr = "subject:This is a test.\r\n";
    const paddedStr = apis.padString(subjectStr, 256);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractSubjectAllIdxes(subjectStr)[0];
    for (let idx = 0; idx < 256; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("subject after new line", async () => {
    const subjectStr = "dummy\r\nsubject:This is a test.\r\n";
    const paddedStr = apis.padString(subjectStr, 256);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractSubjectAllIdxes(subjectStr)[0];
    for (let idx = 0; idx < 256; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("subject from beginning and non-English case", async () => {
    const subjectStr = "subject:これはテストです。\r\n";
    const paddedStr = apis.padString(subjectStr, 256);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractSubjectAllIdxes(subjectStr)[0];
    for (let idx = 0; idx < 256; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });
});
