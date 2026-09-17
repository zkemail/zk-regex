const circom_tester = require("circom_tester");
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import { fileURLToPath } from "url";
import { describe, it, beforeAll, expect } from "bun:test";
import compiler, {
    genCircuitInputs,
    ProvingFramework,
} from "../../../compiler/pkg";

// ES module equivalent of __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Type definitions for circom_tester
interface CircomTesterOptions {
    include: string;
}

interface Circuit {
    calculateWitness(input: any): Promise<bigint[]>;
    checkConstraints(witness: bigint[]): Promise<void>;
}

interface WasmTester {
    (circuitPath: string, options: CircomTesterOptions): Promise<Circuit>;
}

interface CircomTester {
    wasm: WasmTester;
}

// Type definitions for compiler output
interface CompilerOutput {
    code: string;
    graph: string;
}

interface CircuitInputs {
    type?: string;
    captureGroupIds: number[][];
    captureGroupStarts: number[][];
    inHaystack: number[];
    [key: string]: any;
}

interface Graph {
    [key: string]: any;
}

const option: CircomTesterOptions = {
    include: path.join(__dirname, "../../../node_modules"),
};

const wasm_tester = (circom_tester as CircomTester).wasm;

describe("Email Address Regex", () => {
    let graph: Graph;
    let circuit: Circuit;

    beforeAll(async () => {
        const email_addr_json: string = readFileSync(
            path.join(__dirname, "../../regexes/email_addr.json"),
            "utf8"
        );

        const output: CompilerOutput = compiler.genFromDecomposed(
            email_addr_json,
            "EmailAddr",
            ProvingFramework.Circom
        );

        writeFileSync(
            path.join(__dirname, "../common/email_addr_graph.json"),
            output.graph
        );
        writeFileSync(
            path.join(__dirname, "../common/email_addr_regex.circom"),
            output.code
        );

        graph = JSON.parse(output.graph);
        circuit = await wasm_tester(
            path.join(__dirname, "./circuits/test_email_addr_regex.circom"),
            option
        );
    });

    it("should match email address with to: prefix", async () => {
        const inputString = "to:example@example.com\r\n";
        // IMPORTANT: These values MUST match the circuit instantiation parameters
        // in circuits/tests/circuits/test_email_addr_regex.circom
        // Circuit is compiled with fixed array sizes - changing these requires recompiling
        const maxMatchBytes = 64;
        const maxHaystackBytes = 640;

        const { type, ...circuitInputs }: CircuitInputs = JSON.parse(
            genCircuitInputs(
                JSON.stringify(graph),
                inputString,
                maxHaystackBytes,
                maxMatchBytes,
                ProvingFramework.Circom
            )
        );

        let { captureGroupIds, captureGroupStarts, ...rest } = circuitInputs;
        let captureGroup1Id = captureGroupIds[0];
        let captureGroup1Start = captureGroupStarts[0];
        rest.captureGroup1Id = captureGroup1Id;
        rest.captureGroup1Start = captureGroup1Start;

        const witness = await circuit.calculateWitness(rest);
        await circuit.checkConstraints(witness);

        // Check that the match was valid
        expect(1n).toEqual(witness[1]!);

        // Extract and verify the captured email
        // Extract from capture1 output (starts at witness index 2)
        const capture1Start = 2;
        const captureArray = [];
        for (let i = 0; i < maxMatchBytes; i++) {  // capture1 is maxMatchBytes bytes
            const charCode = Number(witness[capture1Start + i]!);
            if (charCode === 0) break;  // Stop at null terminator
            captureArray.push(String.fromCharCode(charCode));
        }
        const extractedEmail = captureArray.join("");
        expect(extractedEmail).toEqual("example@example.com");
    });

    it("should match email address after name and <", async () => {
        const inputString = "to: example <example@example.com>\r\n";
        // IMPORTANT: These values MUST match the circuit instantiation parameters
        // in circuits/tests/circuits/test_email_addr_regex.circom
        // Circuit is compiled with fixed array sizes - changing these requires recompiling
        const maxMatchBytes = 64;
        const maxHaystackBytes = 640;

        const { type, ...circuitInputs }: CircuitInputs = JSON.parse(
            genCircuitInputs(
                JSON.stringify(graph),
                inputString,
                maxHaystackBytes,
                maxMatchBytes,
                ProvingFramework.Circom
            )
        );

        let { captureGroupIds, captureGroupStarts, ...rest } = circuitInputs;
        let captureGroup1Id = captureGroupIds[0];
        let captureGroup1Start = captureGroupStarts[0];
        rest.captureGroup1Id = captureGroup1Id;
        rest.captureGroup1Start = captureGroup1Start;

        const witness = await circuit.calculateWitness(rest);
        await circuit.checkConstraints(witness);

        // Check that the match was valid
        expect(1n).toEqual(witness[1]!);

        // Extract and verify the captured email
        // Extract from capture1 output (starts at witness index 2)
        const capture1Start = 2;
        const captureArray = [];
        for (let i = 0; i < maxMatchBytes; i++) {  // capture1 is maxMatchBytes bytes
            const charCode = Number(witness[capture1Start + i]!);
            if (charCode === 0) break;  // Stop at null terminator
            captureArray.push(String.fromCharCode(charCode));
        }
        const extractedEmail = captureArray.join("");
        expect(extractedEmail).toEqual("example@example.com");
    });
});
