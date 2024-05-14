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
describe("Dot Regex", () => {
    let circuit1;
    let circuit2;
    beforeAll(async () => {
        writeFileSync(
            path.join(__dirname, "./circuits/dot1_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/dot1.json"),
                    "utf8"
                ),
                "Dot1Regex"
            )
        );
        circuit1 = await wasm_tester(
            path.join(__dirname, "./circuits/test_dot1_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/dot2_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/dot2.json"),
                    "utf8"
                ),
                "Dot2Regex"
            )
        );
        circuit2 = await wasm_tester(
            path.join(__dirname, "./circuits/test_dot2_regex.circom"),
            option
        );
    });

    it("dot1 valid case 1", async () => {
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
                path.join(__dirname, "./circuits/dot1.json"),
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

    // it("dot1 valid case 2", async () => {
    //     const inputStr = `aaaa`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit1.calculateWitness(circuitInputs);
    //     await circuit1.checkConstraints(witness);
    //     expect(1n).toEqual(witness[1]);
    //     const prefixIdxes = apis.extractSubstrIdxes(
    //         inputStr,
    //         readFileSync(
    //             path.join(__dirname, "./circuits/dot1.json"),
    //             "utf8"
    //         )
    //     )[0];
    //     for (let idx = 0; idx < 8; ++idx) {
    //         if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
    //             expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
    //         } else {
    //             expect(0n).toEqual(witness[2 + idx]);
    //         }
    //     }
    // });

    it("dot2 valid case 1", async () => {
        const inputStr = `a6b`;
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
                path.join(__dirname, "./circuits/dot2.json"),
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

    // it("dot2 valid case 2", async () => {
    //     const inputStr = `aa6b`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit2.calculateWitness(circuitInputs);
    //     await circuit2.checkConstraints(witness);
    //     expect(1n).toEqual(witness[1]);
    //     const prefixIdxes = apis.extractSubstrIdxes(
    //         inputStr,
    //         readFileSync(
    //             path.join(__dirname, "./circuits/dot2.json"),
    //             "utf8"
    //         )
    //     )[0];
    //     for (let idx = 0; idx < 8; ++idx) {
    //         if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
    //             expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
    //         } else {
    //             expect(0n).toEqual(witness[2 + idx]);
    //         }
    //     }
    // });

    it("dot2 invalid case 1", async () => {
        const inputStr = `819nc8b8`;
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

    it("dot2 invalid case 2", async () => {
        const inputStr = `78aa6cc8`;
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
