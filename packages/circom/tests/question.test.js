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
describe("Question Regex", () => {
    let circuit1;
    let circuit2;
    let circuit3;
    beforeAll(async () => {
        writeFileSync(
            path.join(__dirname, "./circuits/question1_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/question1.json"),
                    "utf8"
                ),
                "Question1Regex"
            )
        );
        circuit1 = await wasm_tester(
            path.join(__dirname, "./circuits/test_question1_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/question2_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/question2.json"),
                    "utf8"
                ),
                "Question2Regex"
            )
        );
        circuit2 = await wasm_tester(
            path.join(__dirname, "./circuits/test_question2_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/question3_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/question3.json"),
                    "utf8"
                ),
                "Question3Regex"
            )
        );
        circuit3 = await wasm_tester(
            path.join(__dirname, "./circuits/test_question3_regex.circom"),
            option
        );
    });

    it("question1 valid case 1", async () => {
        const inputStr = `b`;
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
                path.join(__dirname, "./circuits/question1.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question1 valid case 2", async () => {
        const inputStr = `ab`;
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
                path.join(__dirname, "./circuits/question1.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question1 valid case 3", async () => {
        const inputStr = `199aabb`;
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
                path.join(__dirname, "./circuits/question1.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question1 invalid case 1", async () => {
        const inputStr = `aaaaaaaa`;
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

    it("question1 invalid case 2", async () => {
        const inputStr = `cccccccc`;
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

    it("question2 valid case 1", async () => {
        const inputStr = `12b`;
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
                path.join(__dirname, "./circuits/question2.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question2 valid case 2", async () => {
        const inputStr = `11x2bb`;
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
                path.join(__dirname, "./circuits/question2.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question2 invalid case 1", async () => {
        const inputStr = `1x2`;
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

    it("question2 invalid case 2", async () => {
        const inputStr = `1xb`;
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

    it("question3 valid case 1", async () => {
        const inputStr = `12c`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/question3.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question3 valid case 2", async () => {
        const inputStr = `12ac`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/question3.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question3 valid case 2", async () => {
        const inputStr = `12bc`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/question3.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question3 valid case 4", async () => {
        const inputStr = `12a12bc1`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/question3.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("question3 invalid case 1", async () => {
        const inputStr = `1ac`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("question3 invalid case 2", async () => {
        const inputStr = `12abc`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("question3 invalid case 3", async () => {
        const inputStr = `12a12b`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });
});
