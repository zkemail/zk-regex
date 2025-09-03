import circom_tester from "circom_tester";
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import { fileURLToPath } from "url";
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
    captureGroupIds: number[];
    captureGroupStarts: number[];
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

// Bun handles timeouts automatically
describe("Bodyhash Regex", () => {
    let graph: Graph;
    let circuit: Circuit;
    
    beforeAll(async () => {
        const body_hash_json: string = readFileSync(
            path.join(__dirname, "../../regexes/body_hash.json"),
            "utf8"
        );
        
        const output: CompilerOutput = compiler.genFromDecomposed(
            body_hash_json,
            "BodyHash",
            ProvingFramework.Circom
        );
        
        writeFileSync(
            path.join(__dirname, "../common/body_hash_graph.json"),
            output.graph
        );
        writeFileSync(
            path.join(__dirname, "../common/body_hash_regex.circom"),
            output.code
        );

        graph = JSON.parse(output.graph);
        circuit = await wasm_tester(
            path.join(__dirname, "./circuits/test_body_hash_regex.circom"),
            option
        );
    });

    it("bodyhash in the header", async () => {
        const signatureField = `dkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=`;
        const bodyHash = signatureField.split("; bh=")[1].split(";")[0];
        
        const { type, ...circuitInputs }: CircuitInputs = JSON.parse(
            genCircuitInputs(
                JSON.stringify(graph),
                signatureField,
                300,
                299,
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
        expect(1n).toEqual(witness[1]);
        
        const extractedBodyHash = Array.from(
            { length: bodyHash.length },
            (_, idx) => String.fromCharCode(Number(witness[2 + idx]))
        ).join("");
        expect(bodyHash).toEqual(extractedBodyHash);
    });

    it("bodyhash after new line", async () => {
        const signatureField = `\r\ndkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=`;
        const bodyHash = signatureField.split("; bh=")[1].split(";")[0];
        
        const { type, ...circuitInputs }: CircuitInputs = JSON.parse(
            genCircuitInputs(
                JSON.stringify(graph),
                signatureField,
                300,
                299,
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
        expect(1n).toEqual(witness[1]);
        
        const extractedBodyHash = Array.from(
            { length: bodyHash.length },
            (_, idx) => String.fromCharCode(Number(witness[2 + idx]))
        ).join("");
        expect(bodyHash).toEqual(extractedBodyHash);
    });

    it("bodyhash in the invalid field", async () => {
        const signatureField = `\r\ndkim-signature:v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20230601; t=1694989812; x=1695594612; dara=google.com; h=to:subject:message-id:date:from:mime-version:from:to:cc:subject :date:message-id:reply-to; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=`;
        const bodyHash = signatureField.split("; bh=")[1].split(";")[0];
        
        const { type, ...circuitInputs }: CircuitInputs = JSON.parse(
            genCircuitInputs(
                JSON.stringify(graph),
                signatureField,
                300,
                299,
                ProvingFramework.Circom
            )
        );
        
        let { captureGroupIds, captureGroupStarts, ...rest } = circuitInputs;
        let captureGroup1Id = captureGroupIds[0];
        let captureGroup1Start = captureGroupStarts[0];
        rest.captureGroup1Id = captureGroup1Id;
        rest.captureGroup1Start = captureGroup1Start;
        
        rest.inHaystack.splice(2, 0, 116, 111, 58, 32);
        rest.inHaystack = rest.inHaystack.slice(0, 1024);
        
        await expect(
            (async () => {
                const witness = await circuit.calculateWitness(rest);
                await circuit.checkConstraints(witness);
            })()
        ).rejects.toThrow();
    });
});