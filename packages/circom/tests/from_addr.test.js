import circom_tester from "circom_tester";
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import apis from "../../apis/pkg";
import compiler from "../../compiler/pkg";
const option = {
  include: path.join(__dirname, "../../../node_modules"),
};
const wasm_tester = circom_tester.wasm;

jest.setTimeout(600000);
describe("From Addr Regex", () => {
  let circuit;
  beforeAll(async () => {
    {
      const email_addr_json = readFileSync(
        path.join(__dirname, "../circuits/common/from_all.json"),
        "utf8"
      );
      const circom = compiler.genFromDecomposed(
        email_addr_json,
        "FromAllRegex"
      );
      writeFileSync(
        path.join(__dirname, "../circuits/common/from_all_regex.circom"),
        circom
      );
    }
    {
      const email_addr_json = readFileSync(
        path.join(__dirname, "../circuits/common/reversed_bracket.json"),
        "utf8"
      );
      const circom = compiler.genFromDecomposed(
        email_addr_json,
        "ReversedBracketRegex"
      );
      writeFileSync(
        path.join(
          __dirname,
          "../circuits/common/reversed_bracket_regex.circom"
        ),
        circom
      );
    }
    {
      const email_addr_json = readFileSync(
        path.join(__dirname, "../circuits/common/email_addr.json"),
        "utf8"
      );
      const circom = compiler.genFromDecomposed(
        email_addr_json,
        "EmailAddrRegex"
      );
      writeFileSync(
        path.join(__dirname, "../circuits/common/email_addr_regex.circom"),
        circom
      );
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

  it("from field in the invalid field", async () => {
    const fromStr = "\r\nto:from:Sora Suegami <suegamisora@gmail.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    async function failFn() {
      await circuit.calculateWitness(circuitInputs);
    }
    await expect(failFn).rejects.toThrow();
  });

  it('invalid from field with 255', async () => {
    const fromStr = `from:Sora Suegami <suegamisora@gmail.com>\r\n`;
    let paddedStr = apis.padString(fromStr, 1022);
    paddedStr.unshift(49);
    paddedStr.unshift(255);
    const circuitInputs = {
      msg: paddedStr
    };
    async function failFn() {
      const witness = await circuit.calculateWitness(circuitInputs);
      await circuit.checkConstraints(witness);
    }
    await expect(failFn).rejects.toThrow();
  });

  it("from field containing @ in the name part", async () => {
    const fromStr = "from:Sora Suegami <suegamisora@gmail.com@dummy.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    expect("suegamisora@gmail.com@dummy.com").toEqual(fromStr.slice(prefixIdxes[0], prefixIdxes[1]));
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field starting from @", async () => {
    const fromStr = "from:Sora Suegami <@gmail.com@dummy.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    expect("@gmail.com@dummy.com").toEqual(fromStr.slice(prefixIdxes[0], prefixIdxes[1]));
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field with double <> 1", async () => {
    const fromStr = "from:\"Some name <victim@any-domain>\" <attacker@outlook.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    expect("attacker@outlook.com").toEqual(fromStr.slice(prefixIdxes[0], prefixIdxes[1]));
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });


  it("from field with double <> 2", async () => {
    const fromStr = "from:\"Some name <victim@any-domain>\" < attacker@outlook.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    expect(" attacker@outlook.com").toEqual(fromStr.slice(prefixIdxes[0], prefixIdxes[1]));
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });


  it("from field with double <> 3", async () => {
    const fromStr = "from:\"Some name <victim@any-domain>\" <attacker@outlook.com >\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    // console.log((witness[1]));
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    expect("attacker@outlook.com ").toEqual(fromStr.slice(prefixIdxes[0], prefixIdxes[1]));
    for (let idx = 0; idx < 1024; ++idx) {
      // if (witness[2 + idx] !== 0n) {
      //   console.log('idx:', idx, 'witness:', witness[2 + idx]);
      // }
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("from field with triple <>", async () => {
    const fromStr = "from:\"Some name <victim1@any-domain<victim1@any-domain>>\" <attacker@outlook.com>\r\n";
    const paddedStr = apis.padString(fromStr, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
    expect("attacker@outlook.com").toEqual(fromStr.slice(prefixIdxes[0], prefixIdxes[1]));
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });
});
