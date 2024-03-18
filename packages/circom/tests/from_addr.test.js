const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;
import * as path from "path";
import fs from 'fs'
const apis = require("../../apis");
const wasm = require("../../compiler/wasmpack_nodejs/zk_regex_compiler");
const option = {
  include: path.join(__dirname, "../../../node_modules"),
};

jest.setTimeout(600000);
describe("From Addr Regex", () => {
  let circuit;
  beforeAll(async () => {
    {
      const email_addr_json = fs.readFileSync(path.join(__dirname, "../circuits/common/from_all.json"), "utf8")
      const circom = wasm.gen_from_decomposed_memory(email_addr_json, 'FromAllRegex');
      fs.writeFileSync(path.join(__dirname, "../circuits/common/from_all_regex.circom"), circom);
    }
    {
      const email_addr_json = fs.readFileSync(path.join(__dirname, "../circuits/common/email_addr_with_name.json"), "utf8")
      const circom = wasm.gen_from_decomposed_memory(email_addr_json, 'EmailAddrWithNameRegex');
      fs.writeFileSync(path.join(__dirname, "../circuits/common/email_addr_with_name_regex.circom"), circom);
    }
    {
      const email_addr_json = fs.readFileSync(path.join(__dirname, "../circuits/common/email_addr.json"), "utf8")
      const circom = wasm.gen_from_decomposed_memory(email_addr_json, 'EmailAddrRegex');
      fs.writeFileSync(path.join(__dirname, "../circuits/common/email_addr_regex.circom"), circom);
    }
    circuit = await wasm_tester(
      path.join(__dirname, "./circuits/test_from_addr_regex.circom"),
      option
    );
  });

  it("from field from beginning case 1", async () => {
    const fromStr = "from:suegamisora@gmail.com\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field from beginning case 2", async () => {
    const fromStr = "from:Sora Suegami <suegamisora@gmail.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field from beginning case 3 (email address as a name)", async () => {
    const fromStr = "from:dummy@example.com<suegamisora@gmail.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field from beginning case 4 (non-English string is used as a name)", async () => {
    const fromStr = 'from: "末神奏宙" <suegamisora@gmail.com>\r\n';
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field after new line case 1", async () => {
    const fromStr = "dummy\r\nfrom:suegamisora@gmail.com\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field after new line case 2", async () => {
    const fromStr = "dummy\r\nfrom:Sora Suegami <suegamisora@gmail.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field after new line case 3 (email address as a name)", async () => {
    const fromStr =
      "dummy\r\nfrom:dummy@example.com<suegamisora@gmail.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field after new line case 4 (non-English string is used as a name)", async () => {
    const fromStr = 'dummy\r\nfrom: "末神奏宙" <suegamisora@gmail.com>\r\n';
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });
});
