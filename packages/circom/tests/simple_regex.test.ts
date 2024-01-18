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
describe("Simple Regex", () => {
    let circuit;
    beforeAll(async () => {
        compiler.genFromRaw(
            "1=(a|b) (2=(b|c)+ )+d",
            {
                substrsJsonPath: path.join(__dirname, "./circuits/simple_regex_substrs.json"),
                circomFilePath: path.join(__dirname, "./circuits/simple_regex.circom"),
                templateName: "SimpleRegex",
                genSubstrs: true
            }
        );
        circuit = await wasm_tester(path.join(__dirname, "./circuits/test_simple_regex.circom"), option);
    });

    it("case 1", async () => {
        const input = "1=a 2=b d";
        const paddedStr = apis.padString(input, 64);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_simple_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const revealedIdx = [[2], [6], [8]];
        for (let substr_idx = 0; substr_idx < 3; ++substr_idx) {
            for (let idx = 0; idx < 64; ++idx) {
                if (revealedIdx[substr_idx].includes(idx)) {
                    expect(BigInt(paddedStr[idx])).toEqual(witness[2 + 64 * substr_idx + idx]);
                } else {
                    expect(0n).toEqual(witness[2 + 64 * substr_idx + idx]);
                }
            }
        }
    });

    it("case 2", async () => {
        const input = "1=a 2=b 2=bc 2=c d";
        const paddedStr = apis.padString(input, 64);
        const circuitInputs = {
            msg: paddedStr,
        };
        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_simple_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const revealedIdx = [[2], [6, 10, 11, 15], [17]];
        for (let substr_idx = 0; substr_idx < 3; ++substr_idx) {
            for (let idx = 0; idx < 64; ++idx) {
                if (revealedIdx[substr_idx].includes(idx)) {
                    expect(BigInt(paddedStr[idx])).toEqual(witness[2 + 64 * substr_idx + idx]);
                } else {
                    expect(0n).toEqual(witness[2 + 64 * substr_idx + idx]);
                }
            }
        }
    });

    it("case 3", async () => {
        const input = "1=a 2=b 2=bc 2=c da 1=a 2=cb 2=c 2=b dd";
        const paddedStr = apis.padString(input, 64);
        const circuitInputs = {
            msg: paddedStr,
        };

        // const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_simple_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const revealedIdx = [[2, 22], [6, 10, 11, 15, 26, 27, 31, 35], [17, 37]];
        for (let substr_idx = 0; substr_idx < 3; ++substr_idx) {
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
