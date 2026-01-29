const circom_tester = require("circom_tester");
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import { fileURLToPath } from "url";
import { describe, it, beforeAll, expect } from "bun:test";
import compiler, {
    genCircuitInputs,
    ProvingFramework,
} from "../../../compiler/pkg";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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

/**
 * Extract a captured string from the witness.
 * @param witness - The witness array from calculateWitness()
 * @param startIndex - The starting index in the witness array for this capture
 * @param maxLength - Maximum length of the capture buffer
 * @returns The captured string (stops at null terminator)
 */
function extractCaptureFromWitness(
    witness: bigint[],
    startIndex: number,
    maxLength: number
): string {
    const chars: string[] = [];
    for (let i = 0; i < maxLength; i++) {
        const charCode = Number(witness[startIndex + i]!);
        if (charCode === 0) break; // Stop at null terminator
        chars.push(String.fromCharCode(charCode));
    }
    return chars.join("");
}

describe("Short Capture Tests (1-char captures)", () => {
    describe("From All Header", () => {
        let graph: Graph;
        let circuit: Circuit;
        const maxMatchBytes = 64;
        const maxHaystackBytes = 640;

        beforeAll(async () => {
            const regex_json: string = readFileSync(
                path.join(__dirname, "../../regexes/from_all.json"),
                "utf8"
            );

            const output: CompilerOutput = compiler.genFromDecomposed(
                regex_json,
                "FromAll",
                ProvingFramework.Circom
            );

            writeFileSync(
                path.join(__dirname, "../common/from_all_graph.json"),
                output.graph
            );
            writeFileSync(
                path.join(__dirname, "../common/from_all_regex.circom"),
                output.code
            );

            graph = JSON.parse(output.graph);
            circuit = await wasm_tester(
                path.join(__dirname, "./circuits/test_from_all_regex.circom"),
                option
            );
        });

        it("should match 1-char capture: from:x\\r\\n -> captures 'x'", async () => {
            const inputString = "from:x\r\n";

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

            // Verify match was valid
            expect(witness[1]!).toEqual(1n);

            // Extract and verify the exact captured value (single character!)
            const capturedValue = extractCaptureFromWitness(witness, 2, maxMatchBytes);
            expect(capturedValue).toEqual("x");
        });
    });

    describe("Mixed Capture Groups (1-char + multi-char)", () => {
        let graph: Graph;
        let circuit: Circuit;
        const maxMatchBytes = 64;
        const maxHaystackBytes = 640;
        // Capture group 1 max length is 1, capture group 2 max length is 64
        const capture1MaxLength = 1;
        const capture2MaxLength = 64;

        beforeAll(async () => {
            const regex_json: string = readFileSync(
                path.join(__dirname, "../../regexes/mixed_capture_length.json"),
                "utf8"
            );

            const output: CompilerOutput = compiler.genFromDecomposed(
                regex_json,
                "MixedCaptureLength",
                ProvingFramework.Circom
            );

            writeFileSync(
                path.join(__dirname, "../common/mixed_capture_length_graph.json"),
                output.graph
            );
            writeFileSync(
                path.join(__dirname, "../common/mixed_capture_length_regex.circom"),
                output.code
            );

            graph = JSON.parse(output.graph);
            circuit = await wasm_tester(
                path.join(__dirname, "./circuits/test_mixed_capture_length_regex.circom"),
                option
            );
        });

        it("should capture 'a' and 'hello' from 'a_hello'", async () => {
            const inputString = "a_hello";

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
            rest.captureGroup1Id = captureGroupIds[0];
            rest.captureGroup1Start = captureGroupStarts[0];
            rest.captureGroup2Id = captureGroupIds[1];
            rest.captureGroup2Start = captureGroupStarts[1];

            const witness = await circuit.calculateWitness(rest);
            await circuit.checkConstraints(witness);

            // Verify match was valid
            expect(witness[1]!).toEqual(1n);

            // Witness layout: [1]=isValid, [2..2+capture1MaxLength]=capture1, [2+capture1MaxLength..]=capture2
            const capture1 = extractCaptureFromWitness(witness, 2, capture1MaxLength);
            const capture2 = extractCaptureFromWitness(witness, 2 + capture1MaxLength, capture2MaxLength);

            expect(capture1).toEqual("a");
            expect(capture2).toEqual("hello");
        });

        it("should capture 'x' and 'y' from 'x_y' (both 1-char)", async () => {
            const inputString = "x_y";

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
            rest.captureGroup1Id = captureGroupIds[0];
            rest.captureGroup1Start = captureGroupStarts[0];
            rest.captureGroup2Id = captureGroupIds[1];
            rest.captureGroup2Start = captureGroupStarts[1];

            const witness = await circuit.calculateWitness(rest);
            await circuit.checkConstraints(witness);

            // Verify match was valid
            expect(witness[1]!).toEqual(1n);

            // Extract captures
            const capture1 = extractCaptureFromWitness(witness, 2, capture1MaxLength);
            const capture2 = extractCaptureFromWitness(witness, 2 + capture1MaxLength, capture2MaxLength);

            expect(capture1).toEqual("x");
            expect(capture2).toEqual("y");
        });

        it("should capture 'a' and 'bcdef' from 'a_bcdef'", async () => {
            const inputString = "a_bcdef";

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
            rest.captureGroup1Id = captureGroupIds[0];
            rest.captureGroup1Start = captureGroupStarts[0];
            rest.captureGroup2Id = captureGroupIds[1];
            rest.captureGroup2Start = captureGroupStarts[1];

            const witness = await circuit.calculateWitness(rest);
            await circuit.checkConstraints(witness);

            // Verify match was valid
            expect(witness[1]!).toEqual(1n);

            // Extract captures
            const capture1 = extractCaptureFromWitness(witness, 2, capture1MaxLength);
            const capture2 = extractCaptureFromWitness(witness, 2 + capture1MaxLength, capture2MaxLength);

            expect(capture1).toEqual("a");
            expect(capture2).toEqual("bcdef");
        });
    });
});
