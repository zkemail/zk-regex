import circom_tester from "circom_tester";
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import compiler, {
    genCircuitInputs,
    ProvingSystem,
} from "../../../compiler/pkg";
const option = {
    include: path.join(__dirname, "../../node_modules"),
};
const wasm_tester = circom_tester.wasm;

jest.setTimeout(600000);
describe("Bodyhash Regex", () => {
    let graph;
    let circuit;
    beforeAll(async () => {
        const body_hash_json = readFileSync(
            path.join(__dirname, "../common/body_hash.json"),
            "utf8"
        );
        const output = compiler.genFromDecomposed(
            body_hash_json,
            "BodyHash",
            ProvingSystem.Circom
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
        const { type, ...circuitInputs } = JSON.parse(
            genCircuitInputs(
                JSON.stringify(graph),
                signatureField,
                1024,
                1023,
                ProvingSystem.Circom
            )
        );

        const witness = await circuit.calculateWitness(circuitInputs);
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
        const { type, ...circuitInputs } = JSON.parse(
            genCircuitInputs(
                JSON.stringify(graph),
                signatureField,
                1024,
                1023,
                ProvingSystem.Circom
            )
        );
        const witness = await circuit.calculateWitness(circuitInputs);
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
        const { type, ...circuitInputs } = JSON.parse(
            genCircuitInputs(
                JSON.stringify(graph),
                signatureField,
                1024,
                1023,
                ProvingSystem.Circom
            )
        );
        circuitInputs.inHaystack.splice(2, 0, 116, 111, 58, 32);
        circuitInputs.inHaystack = circuitInputs.inHaystack.slice(0, 1024);
        await expect(
            (async () => {
                const witness = await circuit.calculateWitness(circuitInputs);
                await circuit.checkConstraints(witness);
            })()
        ).rejects.toThrow();
    });
});
