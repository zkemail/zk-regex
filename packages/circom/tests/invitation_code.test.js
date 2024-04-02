import circom_tester from "circom_tester";
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import apis from "../../apis/pkg";
import compiler from "../../compiler/pkg";
const option = {
    include: path.join(__dirname, "../../../node_modules"),
};
const wasm_tester = circom_tester.wasm;

jest.setTimeout(300000);
describe("Invitation Code Decomposed (taken from ether-email-auth)", () => {
    let circuit;
    beforeAll(async () => {
        const email_addr_json = readFileSync(
            path.join(__dirname, "./circuits/invitation_code_with_prefix.json"),
            "utf8"
        );
        const circom = compiler.genFromDecomposed(
            email_addr_json,
            "InvitationCodeWithPrefixRegex"
        );
        writeFileSync(
            path.join(__dirname, "./circuits/invitation_code_with_prefix_regex.circom"),
            circom
        );
        circuit = await wasm_tester(
            path.join(
                __dirname,
                "./circuits/test_invitation_code_with_prefix_regex.circom"
            ),
            option
        );
    });

    it("case 1", async () => {
        const input =
            "Re: Accept guardian request for 0x04884491560f38342C56E26BDD0fEAbb68E2d2FC Code 01eb9b204cc24c3baee11accc37d253a9c53e92b1a2cc07763475c135d575b76";
        const paddedStr = apis.padString(input, 256);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit.calculateWitness(circuitInputs);
        await circuit.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const revealedIdx = [
            [74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143],
        ];
        for (let substr_idx = 0; substr_idx < 1; ++substr_idx) {
            for (let idx = 0; idx < 256; ++idx) {
                if (revealedIdx[substr_idx].includes(idx)) {
                    expect(BigInt(paddedStr[idx])).toEqual(
                        witness[2 + 256 * substr_idx + idx]
                    );
                } else {
                    expect(0n).toEqual(witness[2 + 256 * substr_idx + idx]);
                }
            }
        }
    });
});
