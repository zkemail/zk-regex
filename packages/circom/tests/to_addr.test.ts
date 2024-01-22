const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;
import * as path from "path";
const apis = require("../../apis");
const option = {
    include: path.join(__dirname, "../../../node_modules")
};
const compiler = require("../../compiler");

jest.setTimeout(240000);
describe("To Addr Regex", () => {
    let circuit;
    beforeAll(async () => {
        compiler.genFromDecomposed(path.join(__dirname, "../circuits/common/to_all.json"), {
            circomFilePath: path.join(__dirname, "../circuits/common/to_all_regex.circom"),
            templateName: "ToAllRegex",
            genSubstrs: true
        });
        compiler.genFromDecomposed(path.join(__dirname, "../circuits/common/email_addr_with_name.json"), {
            circomFilePath: path.join(__dirname, "../circuits/common/email_addr_with_name_regex.circom"),
            templateName: "EmailAddrWithNameRegex",
            genSubstrs: true
        });
        compiler.genFromDecomposed(path.join(__dirname, "../circuits/common/email_addr.json"), {
            circomFilePath: path.join(__dirname, "../circuits/common/email_addr_regex.circom"),
            templateName: "EmailAddrRegex",
            genSubstrs: true
        });
        circuit = await wasm_tester(path.join(__dirname, "./circuits/test_to_addr_regex.circom"), option);
    });

    it("to field from beginning case 1", async () => {
        const toStr = "to:adityabisht@gmail.com\r\n";
        const paddedStr = apis.padString(toStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractToAddrIdxes(toStr)[0];
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });


    it("to field from beginning case 2", async () => {
        const toStr = "to:Aditya Bisht <adityabisht@gmail.com>\r\n";
        const paddedStr = apis.padString(toStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractToAddrIdxes(toStr)[0];
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("to field from beginning case 3 (email address as a name)", async () => {
        const toStr = "to:dummy@example.com<adityabisht@gmail.com>\r\n";
        const paddedStr = apis.padString(toStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractToAddrIdxes(toStr)[0];
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("to field from beginning case 4 (non-English string is used as a name)", async () => {
        const toStr = "to: \"末神奏宙\" <adityabisht@gmail.com>\r\n";
        const paddedStr = apis.padString(toStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractToAddrIdxes(toStr)[0];
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("to field after new line case 1", async () => {
        const toStr = "dummy\r\nto:adityabisht@gmail.com\r\n";
        const paddedStr = apis.padString(toStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractToAddrIdxes(toStr)[0];
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("to field after new line case 2", async () => {
        const toStr = "dummy\r\nto:Sora Suegami <adityabisht@gmail.com>\r\n";
        const paddedStr = apis.padString(toStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractToAddrIdxes(toStr)[0];
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("to field after new line case 3 (email address as a name)", async () => {
        const toStr = "dummy\r\nto:dummy@example.com<adityabisht@gmail.com>\r\n";
        const paddedStr = apis.padString(toStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractToAddrIdxes(toStr)[0];
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("to field after new line case 4 (non-English string is used as a name)", async () => {
        const toStr = "dummy\r\nto: \"末神奏宙\" <adityabisht@gmail.com>\r\n";
        const paddedStr = apis.padString(toStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractToAddrIdxes(toStr)[0];
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });
});