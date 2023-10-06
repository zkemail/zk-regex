const ff = require('ffjavascript');
const stringifyBigInts = ff.utils.stringifyBigInts;
const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;
import * as path from "path";
const p = "21888242871839275222246405745257275088548364400416034343698204186575808495617";
const field = new ff.F1Field(p);
const apis = require("../../apis");
const option = {
    include: path.join(__dirname, "../../../node_modules")
};
import { readFileSync } from "fs";
const compiler = require("../../compiler");

jest.setTimeout(240000);
describe("From Addr Regex", () => {
    let circuit;
    beforeAll(async () => {
        compiler.genFromDecomposed(path.join(__dirname, "../circuits/common/from_all.json"), {
            circomFilePath: path.join(__dirname, "../circuits/common/from_all_regex.circom"),
            templateName: "FromAllRegex",
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
        circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
    });

    it("from field from beginning case 1", async () => {
        const fromStr = "from:suegamisora@gmail.com\r\n";
        // const revealed = "suegamisora@gmail.com";
        const paddedStr = apis.padString(fromStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
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
        // const revealed = "suegamisora@gmail.com";
        // const prefixLen = "from:Sora Suegami <".length;
        const paddedStr = apis.padString(fromStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        // console.log(paddedStr);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
        // for (let idx = 0; idx < revealed.length; ++idx) {
        //     expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        // }
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
        // const revealed = "suegamisora@gmail.com";
        // const prefixLen = "from:Sora Suegami <".length;
        const paddedStr = apis.padString(fromStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        // console.log(paddedStr);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
        // for (let idx = 0; idx < revealed.length; ++idx) {
        //     expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        // }
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("from field from beginning case 4 (non-English string is used as a name)", async () => {
        const fromStr = "from: \"末神奏宙\" <suegamisora@gmail.com>\r\n";
        // const revealed = "suegamisora@gmail.com";
        // const prefixLen = "from:Sora Suegami <".length;
        const paddedStr = apis.padString(fromStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        // console.log(paddedStr);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
        // for (let idx = 0; idx < revealed.length; ++idx) {
        //     expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        // }
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
        const revealed = "suegamisora@gmail.com";
        // const prefixLen = "dummy\r\nfrom:".length;
        const paddedStr = apis.padString(fromStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
        // for (let idx = 0; idx < revealed.length; ++idx) {
        //     expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        // }
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
        const revealed = "suegamisora@gmail.com";
        // const prefixLen = "dummy\r\nfrom:Sora Suegami <".length;
        const paddedStr = apis.padString(fromStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
        // for (let idx = 0; idx < revealed.length; ++idx) {
        //     expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        // }
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("from field after new line case 3 (email address as a name)", async () => {
        const fromStr = "dummy\r\nfrom:dummy@example.com<suegamisora@gmail.com>\r\n";
        // const revealed = "suegamisora@gmail.com";
        // const prefixLen = "from:Sora Suegami <".length;
        const paddedStr = apis.padString(fromStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        // console.log(paddedStr);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
        // for (let idx = 0; idx < revealed.length; ++idx) {
        //     expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        // }
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("from field after new line case 4 (non-English string is used as a name)", async () => {
        const fromStr = "dummy\r\nfrom: \"末神奏宙\" <suegamisora@gmail.com>\r\n";
        // const revealed = "suegamisora@gmail.com";
        // const prefixLen = "from:Sora Suegami <".length;
        const paddedStr = apis.padString(fromStr, 1024);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_from_addr_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        // console.log(paddedStr);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractFromAddrIdxes(fromStr)[0];
        // for (let idx = 0; idx < revealed.length; ++idx) {
        //     expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        // }
        for (let idx = 0; idx < 1024; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

});