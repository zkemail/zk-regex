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
describe("Email Domain Regex", () => {
  let circuit;
  beforeAll(async () => {
    const email_addr_json = readFileSync(
      path.join(__dirname, "../circuits/common/email_domain.json"),
      "utf8"
    );
    const circom = compiler.genFromDecomposed(
      email_addr_json,
      "EmailDomainRegex"
    );
    writeFileSync(
      path.join(__dirname, "../circuits/common/email_domain_regex.circom"),
      circom
    );
    circuit = await wasm_tester(
      path.join(__dirname, "./circuits/test_email_domain_regex.circom"),
      option
    );
  });

  it("test a regex of an email domain", async () => {
    const emailAddr = "suegamisora@gmail.com";
    const paddedStr = apis.padString(emailAddr, 256);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractEmailDomainIdxes(emailAddr)[0];
    for (let idx = 0; idx < 256; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("accepts a quoted local part without a second @", async () => {
    const emailAddr = '"sue"@gmail.com';
    const witness = await circuit.calculateWitness({ msg: apis.padString(emailAddr, 256) });
    await circuit.checkConstraints(witness);
    expect(witness[1]).toBe(1n);
    expect(String.fromCharCode(...witness.slice(2, 258).filter((byte) => byte !== 0n).map(Number))).toBe('gmail.com');
  });

  it("rejects an @ inside the name part", async () => {
    const emailAddr = "suegamisora@gmail.com@dummy.com";
    const paddedStr = apis.padString(emailAddr, 256);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(0n).toEqual(witness[1]);
    expect(witness.slice(2, 258).every((byte) => byte === 0n)).toBe(true);
  });

  it("rejects an address starting with @", async () => {
    const emailAddr = "@gmail.com@dummy.com";
    const paddedStr = apis.padString(emailAddr, 256);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(0n).toEqual(witness[1]);
    expect(witness.slice(2, 258).every((byte) => byte === 0n)).toBe(true);
  });

  it.each([
    '"victim@gmail.com"@spam.co.kr',
    '/victim@gmail.com/@spam.co.kr',
  ])('rejects an embedded address in %s', async (emailAddr) => {
    const witness = await circuit.calculateWitness({ msg: apis.padString(emailAddr, 256) });
    await circuit.checkConstraints(witness);
    expect(witness[1]).toBe(0n);
    expect(witness.slice(2, 258).every((byte) => byte === 0n)).toBe(true);
  });
});
