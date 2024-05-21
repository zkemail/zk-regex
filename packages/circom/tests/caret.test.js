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
describe("Caret Regex", () => {
    let circuit1;
    let circuit2;
    let circuit3;
    let circuit4;
    let circuit5;
    beforeAll(async () => {
        writeFileSync(
            path.join(__dirname, "./circuits/caret1_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/caret1.json"),
                    "utf8"
                ),
                "Caret1Regex"
            )
        );
        circuit1 = await wasm_tester(
            path.join(__dirname, "./circuits/test_caret1_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/caret2_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/caret2.json"),
                    "utf8"
                ),
                "Caret2Regex"
            )
        );
        circuit2 = await wasm_tester(
            path.join(__dirname, "./circuits/test_caret2_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/caret3_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/caret3.json"),
                    "utf8"
                ),
                "Caret3Regex"
            )
        );
        circuit3 = await wasm_tester(
            path.join(__dirname, "./circuits/test_caret3_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/caret4_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/caret4.json"),
                    "utf8"
                ),
                "Caret4Regex"
            )
        );
        circuit4 = await wasm_tester(
            path.join(__dirname, "./circuits/test_caret4_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/caret5_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/caret5.json"),
                    "utf8"
                ),
                "Caret5Regex"
            )
        );
        circuit5 = await wasm_tester(
            path.join(__dirname, "./circuits/test_caret5_regex.circom"),
            option
        );
    });

    it("caret1 valid case 1", async () => {
        const inputStr = `a`;
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
                path.join(__dirname, "./circuits/caret1.json"),
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

    it("caret1 valid case 2", async () => {
        const inputStr = `abnjknda`;
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
                path.join(__dirname, "./circuits/caret1.json"),
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

    it("caret1 invalid case 1", async () => {
        const inputStr = `ba`;
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

    it("caret1 invalid case 2", async () => {
        const inputStr = `bav`;
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

    
    it("caret2 valid case 1", async () => {
        const inputStr = `abc`;
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
                path.join(__dirname, "./circuits/caret2.json"),
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

    it("caret2 valid case 2", async () => {
        const inputStr = `bca`;
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
                path.join(__dirname, "./circuits/caret2.json"),
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

    it("caret2 valid case 3", async () => {
        const inputStr = `cab`;
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
                path.join(__dirname, "./circuits/caret2.json"),
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

    it("caret2 invalid case 1", async () => {
        const inputStr = `7abc9mna`;
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

    it("caret3 valid case 1", async () => {
        const inputStr = `bb817267`;
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
                path.join(__dirname, "./circuits/caret3.json"),
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

    it("caret3 valid case 2", async () => {
        const inputStr = `818abbb9`;
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
                path.join(__dirname, "./circuits/caret3.json"),
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

    it("caret3 invalid case 1", async () => {
        const inputStr = `81b`;
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

    it("caret4 valid case 1", async () => {
        const inputStr = `xabaaabb`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/caret4.json"),
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

    it("caret4 valid case 2", async () => {
        const inputStr = `xbaab82a`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/caret4.json"),
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

    it("caret4 valid case 3", async () => {
        const inputStr = `7w1\nxabb`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/caret4.json"),
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

    it("caret4 valid case 4", async () => {
        const inputStr = `7w\nxbbb9`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/caret4.json"),
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


    it("caret4 invalid case 1", async () => {
        const inputStr = `7w1nxaba`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("caret4 invalid case 2", async () => {
        const inputStr = `abba\nx`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("caret5 valid case 1", async () => {
        const inputStr = `xdefabc1`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit5.calculateWitness(circuitInputs);
        await circuit5.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/caret5.json"),
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

    it("caret5 valid case 2", async () => {
        const inputStr = `9\nx9eabc`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit5.calculateWitness(circuitInputs);
        await circuit5.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/caret5.json"),
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

    it("caret5 invalid case 1", async () => {
        const inputStr = `xabc`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit5.calculateWitness(circuitInputs);
        await circuit5.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("caret5 invalid case 2", async () => {
        const inputStr = `1\ndef`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit5.calculateWitness(circuitInputs);
        await circuit5.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });



    it("caret5 invalid case 3", async () => {
        const inputStr = `a8abc8`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit5.calculateWitness(circuitInputs);
        await circuit5.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("caret5 invalid case 4", async () => {
        const inputStr = `71\na81ma`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit5.calculateWitness(circuitInputs);
        await circuit5.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

});
