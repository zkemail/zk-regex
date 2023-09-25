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

jest.setTimeout(120000);
describe("Subject All Regex", () => {
    it("subject from beginning", async () => {
        const subjectStr = "subject:This is a test.\r\n";
        const revealed = "This is a test.";
        // const prefixLen = "subject:".length;
        const paddedStr = apis.padString(subjectStr, 256);
        const circuitInputs = {
            msg: paddedStr,
        };
        const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_subject_all_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdx = apis.extractSubstrIdxes(subjectStr, readFileSync(path.join(__dirname, "../circuits/common/subject_all.json"), "utf8"))[0][0];
        for (let idx = 0; idx < revealed.length; ++idx) {
            expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        }
    });

    it("subject after new line", async () => {
        const subjectStr = "dummy\r\nsubject:This is a test.\r\n";
        const revealed = "This is a test.";
        // const prefixLen = "dummy\r\nsubject:".length;
        const paddedStr = apis.padString(subjectStr, 256);
        console.log(paddedStr);
        const circuitInputs = {
            msg: paddedStr,
        };
        const circuit = await wasm_tester(path.join(__dirname, "./circuits/test_subject_all_regex.circom"), option);
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        // console.log(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdx = apis.extractSubstrIdxes(subjectStr, readFileSync(path.join(__dirname, "../circuits/common/subject_all.json"), "utf8"))[0][0];
        for (let idx = 0; idx < revealed.length; ++idx) {
            expect(BigInt(paddedStr[prefixIdx + idx])).toEqual(witness[2 + prefixIdx + idx]);
        }
    });
});