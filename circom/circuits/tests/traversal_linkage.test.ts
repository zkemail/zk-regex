const circom_tester = require("circom_tester");
import * as path from "path";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { describe, it, beforeAll, expect } from "bun:test";
import compiler, {
    genCircuitInputs,
    ProvingFramework,
} from "../../../compiler/pkg";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const option = { include: path.join(__dirname, "../../../node_modules") };

// IMPORTANT: must match circuits/test_subject_all_full_length_regex.circom
const maxHaystackBytes = 128;
const maxMatchBytes = 64;

// "subject:" (8) + 54 bytes + "\r\n" (2) == maxMatchBytes
const FULL_WINDOW_SUBJECT = "subject:" + "a".repeat(54) + "\r\n";

/**
 * Soundness regression test for the state-traversal linkage.
 *
 * Every step i of the asserted path must satisfy nextStates[i] == currStates[i+1], including the
 * link into the very last slot of the match window. An earlier version of the generated circuits
 * stopped one step short, so when matchLength == maxMatchBytes the final transition was
 * unconstrained with respect to the rest of the path and a prover could jump straight into an
 * accept state.
 */
describe("Traversal linkage (matchLength == maxMatchBytes)", () => {
    let graph: string;
    let circuit: any;

    const inputsFor = (haystack: string) => {
        const { type, captureGroupIds, captureGroupStarts, ...rest } = JSON.parse(
            genCircuitInputs(
                graph,
                haystack,
                maxHaystackBytes,
                maxMatchBytes,
                ProvingFramework.Circom
            )
        );
        rest.captureGroup1Id = captureGroupIds[0];
        rest.captureGroup1Start = captureGroupStarts[0];
        return rest;
    };

    beforeAll(async () => {
        const decomposed = readFileSync(
            path.join(__dirname, "../../regexes/subject_all.json"),
            "utf8"
        );
        graph = compiler.genFromDecomposed(
            decomposed,
            "SubjectAll",
            ProvingFramework.Circom
        ).graph;
        circuit = await circom_tester.wasm(
            path.join(__dirname, "./circuits/test_subject_all_full_length_regex.circom"),
            option
        );
    });

    it("accepts an honest match that fills the whole window", async () => {
        const inputs = inputsFor(FULL_WINDOW_SUBJECT);
        expect(Number(inputs.matchLength)).toEqual(maxMatchBytes);

        const witness = await circuit.calculateWitness(inputs);
        await circuit.checkConstraints(witness);
        expect(witness[1]).toEqual(1n);
    });

    it("rejects a forged final transition that is not linked to the path", async () => {
        // Start from the honest witness, then swap the '\r' for an ordinary byte. The haystack
        // becomes "subject:aaa...aX\n", which does NOT match (?:\r\n|^)subject:([^\r\n]+)\r\n.
        const inputs = inputsFor(FULL_WINDOW_SUBJECT);
        const last = maxMatchBytes - 1;
        const loopState = inputs.currStates[last - 2]; // state while consuming [^\r\n]+

        inputs.inHaystack[last - 1] = "X".charCodeAt(0);
        // Step last-1 now stays in the capture loop, which is a valid transition on its own...
        inputs.currStates[last - 1] = loopState;
        inputs.nextStates[last - 1] = loopState;
        inputs.captureGroup1Id[last - 1] = 1;
        inputs.captureGroup1Start[last - 1] = 0;
        // ...while the final step still claims "<state after \r> -[\n]-> accept", which is also a
        // valid transition on its own but does not follow from the previous step.
        expect(inputs.nextStates[last - 1]).not.toEqual(inputs.currStates[last]);

        let accepted = false;
        try {
            const witness = await circuit.calculateWitness(inputs);
            await circuit.checkConstraints(witness);
            accepted = witness[1] === 1n;
        } catch {
            accepted = false;
        }
        expect(accepted).toBe(false);
    });
});
