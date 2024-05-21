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
describe("Bodyhash Regex", () => {
  let circuit;
  beforeAll(async () => {
    const email_addr_json = readFileSync(
      path.join(__dirname, "../circuits/common/body_hash.json"),
      "utf8"
    );
    const circom = compiler.genFromDecomposed(
      email_addr_json,
      "BodyHashRegex"
    );
    writeFileSync(
      path.join(__dirname, "../circuits/common/body_hash_regex.circom"),
      circom
    );

    circuit = await wasm_tester(
      path.join(__dirname, "./circuits/test_body_hash_regex.circom"),
      option
    );
  });

  it("bodyhash in the header", async () => {
    const signatureField = `dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=`;
    const paddedStr = apis.padString(signatureField, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractSubstrIdxes(
      signatureField,
      readFileSync(
        path.join(__dirname, "../circuits/common/body_hash.json"),
        "utf8"
      )
    )[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("bodyhash after new line", async () => {
    const signatureField = `\r\ndkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=`;
    const paddedStr = apis.padString(signatureField, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractSubstrIdxes(
      signatureField,
      readFileSync(
        path.join(__dirname, "../circuits/common/body_hash.json"),
        "utf8"
      )
    )[0];
    for (let idx = 0; idx < 1024; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("invalid bodyhash", async () => {
    const signatureField = `\r\nto: dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=`;
    const paddedStr = apis.padString(signatureField, 1024);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(0n).toEqual(witness[1]);
    for (let idx = 0; idx < 1024; ++idx) {
      expect(0n).toEqual(witness[2 + idx]);
    }
  });
});
