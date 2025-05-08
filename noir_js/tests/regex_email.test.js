import fs from "fs";
import os from "os";
import path from "path";
import { generateEmailVerifierInputs } from "@zk-email/zkemail-nr";
import { Noir } from "@noir-lang/noir_js";
import { UltraHonkBackend } from "@aztec/bb.js";
import compiler, {
    genCircuitInputs,
    ProvingSystem,
} from "../../compiler/pkg";


import circuit from "../example/target/timestamp_demo.json";
import graph from "./timestamp_graph.json";

const email = fs.readFileSync(
    path.join(__dirname, "./email.eml"),
);

// default header/ body lengths to use for input gen
const inputParams = {
    maxHeadersLength: 512,
    maxBodyLength: 1024,
};

describe("ZKEmail.nr Circuit Unit Tests", () => {
    let bb;
    let noir;

    beforeAll(() => {
        let num_cpus = os.cpus().length;
        bb = new UltraHonkBackend(circuit.bytecode, { threads: num_cpus });
        noir = new Noir(circuit);
    });

    describe("Simulate Witnesses", () => {
        it("2048-bit DKIM", async () => {
            let emailInputs = await generateEmailVerifierInputs(
                email,
                inputParams,
            );
            let header = Buffer.from(emailInputs.header.storage).toString();
            let regexInputs = JSON.parse(genCircuitInputs(
                JSON.stringify(graph),
                header,
                516, // not sure why it is 512, todo
                100,
                ProvingSystem.Noir
            ));
            regexInputs.in_haystack = undefined; // email input header is haystack
            // fix start indices
            regexInputs.capture_group_start_indices = 
                regexInputs.capture_group_start_indices.map(x => {
                    return (Number(x) - Number(regexInputs.match_start)).toString()
                });
            // combine inputs
            let inputs = { ...emailInputs, ...regexInputs };
            // execute and return public outputs
            let { returnValue } = await noir.execute(inputs);
            let emailNullifier = returnValue[0];
            let pubkeyHash = returnValue[1];
            let captureVec = returnValue[2];
            let substring = Buffer.from(
                captureVec.storage.slice(0, Number(captureVec.len)).map(x => Number(x))
            ).toString();
            console.log("Email Nullifier", emailNullifier);
            console.log("Pubkey Hash", pubkeyHash);
            console.log("Timestamp Substring", substring);
        });
    });
});
