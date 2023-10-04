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
const compiler = require("../../compiler");

jest.setTimeout(120000);
describe("Negate Regex", () => {
    let circuit;
    beforeAll(async () => {
        compiler.genFromDecomposed(path.join(__dirname, "./circuits/negate1.json"), {
            circomFilePath: path.join(__dirname, "./circuits/negate1_regex.circom"),
            templateName: "Negate1Regex",
            genSubstrs: true
        });
        circuit = await wasm_tester(path.join(__dirname, "./circuits/test_negate1_regex.circom"), option);
    });

    it("case 1 with regex 1", async () => {
        const input = "a: ABCDEFG XYZ.";
        const paddedStr = apis.padString(input, 64);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_negate1_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const revealedIdx = [[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]];
        for (let substr_idx = 0; substr_idx < 1; ++substr_idx) {
            for (let idx = 0; idx < 64; ++idx) {
                if (revealedIdx[substr_idx].includes(idx)) {
                    expect(BigInt(paddedStr[idx])).toEqual(witness[2 + 64 * substr_idx + idx]);
                } else {
                    expect(0n).toEqual(witness[2 + 64 * substr_idx + idx]);
                }
            }
        }
    });

    it("case 2 with regex 1", async () => {
        // Spanish character "í" has 2 bytes.
        const input = "a: CRIPTOGRAFíA.";
        const paddedStr = apis.padString(input, 64);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_negate1_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const revealedIdx = [[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]];
        for (let substr_idx = 0; substr_idx < 1; ++substr_idx) {
            for (let idx = 0; idx < 64; ++idx) {
                if (revealedIdx[substr_idx].includes(idx)) {
                    expect(BigInt(paddedStr[idx])).toEqual(witness[2 + 64 * substr_idx + idx]);
                } else {
                    expect(0n).toEqual(witness[2 + 64 * substr_idx + idx]);
                }
            }
        }
    });

    it("case 3 with regex 1", async () => {
        /// Each Japanese character has 3 bytes.
        const input = "a: あいう.";
        const paddedStr = apis.padString(input, 64);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_negate1_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const revealedIdx = [[2, 3, 4, 5, 6, 7, 8, 9, 10, 11]];
        for (let substr_idx = 0; substr_idx < 1; ++substr_idx) {
            for (let idx = 0; idx < 64; ++idx) {
                if (revealedIdx[substr_idx].includes(idx)) {
                    expect(BigInt(paddedStr[idx])).toEqual(witness[2 + 64 * substr_idx + idx]);
                } else {
                    expect(0n).toEqual(witness[2 + 64 * substr_idx + idx]);
                }
            }
        }
    });

    it("case 4 with regex 1", async () => {
        /// Arabian character "التشفير" has 14 bytes.
        const input = "a: التشفير.";
        const paddedStr = apis.padString(input, 64);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_negate1_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        // console.log(paddedStr);
        expect(1n).toEqual(witness[1]);
        const revealedIdx = [[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]];
        for (let substr_idx = 0; substr_idx < 1; ++substr_idx) {
            for (let idx = 0; idx < 64; ++idx) {
                if (revealedIdx[substr_idx].includes(idx)) {
                    expect(BigInt(paddedStr[idx])).toEqual(witness[2 + 64 * substr_idx + idx]);
                } else {
                    expect(0n).toEqual(witness[2 + 64 * substr_idx + idx]);
                }
            }
        }
    });
});