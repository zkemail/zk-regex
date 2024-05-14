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
describe("Revealed Chars Check", () => {
    let circuit1;
    let circuit2;
    beforeAll(async () => {
        writeFileSync(
            path.join(__dirname, "./circuits/reveal_check1_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/reveal_check1.json"),
                    "utf8"
                ),
                "RevealCheck1Regex"
            )
        );
        circuit1 = await wasm_tester(
            path.join(__dirname, "./circuits/test_reveal_check1_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/reveal_check2_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/reveal_check2.json"),
                    "utf8"
                ),
                "RevealCheck2Regex"
            )
        );
        circuit2 = await wasm_tester(
            path.join(__dirname, "./circuits/test_reveal_check2_regex.circom"),
            option
        );
    });

    it("reveal check1 valid case 1", async () => {
        const inputStr = `aba`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/reveal_check1.json"),
                "utf8"
            )
        )[0];
        expect(prefixIdxes).toEqual([0,3]);
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });


    it("reveal check1 valid case 2", async () => {
        const inputStr = `7abaab9`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/reveal_check1.json"),
                "utf8"
            )
        )[0];
        expect(prefixIdxes).toEqual([1,4]);
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("reveal check1 invalid case 1", async () => {
        const inputStr = `aca`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("reveal check1 invalid case 2", async () => {
        const inputStr = `aaa`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("reveal check2 valid case 1", async () => {
        const inputStr = `aa`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/reveal_check2.json"),
                "utf8"
            )
        )[0];
        expect(prefixIdxes).toEqual([0,2]);
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("reveal check2 valid case 2", async () => {
        const inputStr = `ab`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/reveal_check2.json"),
                "utf8"
            )
        )[0];
        expect(prefixIdxes).toEqual([0,2]);
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("reveal check2 valid case 3", async () => {
        const inputStr = `aba`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/reveal_check2.json"),
                "utf8"
            )
        )[0];
        expect(prefixIdxes).toEqual([0,2]);
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("reveal check2 invalid case 1", async () => {
        const inputStr = `ac`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("reveal check2 invalid case 2", async () => {
        const inputStr = `bad`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("reveal check2 invalid case 3", async () => {
        const inputStr = `bad`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    
});
