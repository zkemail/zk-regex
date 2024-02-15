const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;
import * as path from "path";
const apis = require("../../apis");
const option = {
  include: path.join(__dirname, "../../../node_modules"),
};
const compiler = require("../../compiler");

jest.setTimeout(120000);
describe("Message Id Regex", () => {
  let circuit;
  beforeAll(async () => {
    compiler.genFromDecomposed(
      path.join(__dirname, "../circuits/common/message_id.json"),
      {
        circomFilePath: path.join(
          __dirname,
          "../circuits/common/message_id_regex.circom"
        ),
        templateName: "MessageIdRegex",
        genSubstrs: true,
      }
    );
    circuit = await wasm_tester(
      path.join(__dirname, "./circuits/test_message_id_regex.circom"),
      option
    );
  });

  it("message id from beginning", async () => {
    const messageIdStr = `message-id:<CAJ7Y6jdOGRFj4RbA=JU034DwHUnRapUZzqLN4hGkG3ou23dFbw@mail.gmail.com>\r\n`;
    const paddedStr = apis.padString(messageIdStr, 256);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractMessageIdIdxes(messageIdStr)[0];
    for (let idx = 0; idx < 256; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });

  it("subject after new line", async () => {
    const messageIdStr =
      "dummy\r\nmessage-id:<CAJ7Y6jdOGRFj4RbA=JU034DwHUnRapUZzqLN4hGkG3ou23dFbw@mail.gmail.com>\r\n";
    const paddedStr = apis.padString(messageIdStr, 256);
    const circuitInputs = {
      msg: paddedStr,
    };
    const witness = await circuit.calculateWitness(circuitInputs);
    await circuit.checkConstraints(witness);
    expect(1n).toEqual(witness[1]);
    const prefixIdxes = apis.extractMessageIdIdxes(messageIdStr)[0];
    for (let idx = 0; idx < 256; ++idx) {
      if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
        expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
      } else {
        expect(0n).toEqual(witness[2 + idx]);
      }
    }
  });
});
