import circom_tester from "circom_tester";
import * as path from "path";
import { readFileSync, writeFileSync } from "fs";
import apis from "../../apis/pkg";
import compiler from "../../compiler/pkg";
const option = {
  include: path.join(__dirname, "../../../node_modules"),
};
const wasm_tester = circom_tester.wasm;

jest.setTimeout(600000);
describe("Asterisk Regex", () => {
    let circuit1;
    let circuit2;
    let circuit3;
    // let circuit4;
    // let circuit5;
    // let circuit6;
    beforeAll(async () => {
        writeFileSync(
            path.join(__dirname, "./circuits/asterisk1_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/asterisk1.json"),
                    "utf8"
                ),
                "Asterisk1Regex"
            )
        );
        circuit1 = await wasm_tester(
            path.join(__dirname, "./circuits/test_asterisk1_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/asterisk2_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/asterisk2.json"),
                    "utf8"
                ),
                "Asterisk2Regex"
            )
        );
        circuit2 = await wasm_tester(
            path.join(__dirname, "./circuits/test_asterisk2_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/asterisk3_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/asterisk3.json"),
                    "utf8"
                ),
                "Asterisk3Regex"
            )
        );
        circuit3 = await wasm_tester(
            path.join(__dirname, "./circuits/test_asterisk3_regex.circom"),
            option
        );

        // writeFileSync(
        //     path.join(__dirname, "./circuits/asterisk4_regex.circom"),
        //     compiler.genFromDecomposed(
        //         readFileSync(
        //             path.join(__dirname, "./circuits/asterisk4.json"),
        //             "utf8"
        //         ),
        //         "Asterisk4Regex"
        //     )
        // );
        // circuit4 = await wasm_tester(
        //     path.join(__dirname, "./circuits/test_asterisk4_regex.circom"),
        //     option
        // );

        // writeFileSync(
        //     path.join(__dirname, "./circuits/asterisk5_regex.circom"),
        //     compiler.genFromDecomposed(
        //         readFileSync(
        //             path.join(__dirname, "./circuits/asterisk5.json"),
        //             "utf8"
        //         ),
        //         "Asterisk5Regex"
        //     )
        // );
        // circuit5 = await wasm_tester(
        //     path.join(__dirname, "./circuits/test_asterisk5_regex.circom"),
        //     option
        // );

        // writeFileSync(
        //     path.join(__dirname, "./circuits/asterisk6_regex.circom"),
        //     compiler.genFromDecomposed(
        //         readFileSync(
        //             path.join(__dirname, "./circuits/asterisk6.json"),
        //             "utf8"
        //         ),
        //         "Asterisk6Regex"
        //     )
        // );
        // circuit6 = await wasm_tester(
        //     path.join(__dirname, "./circuits/test_asterisk6_regex.circom"),
        //     option
        // );
    });

    it("asterisk1 valid case 1", async () => {
        const inputStr = `xb`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk1.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("asterisk1 valid case 2", async () => {
        const inputStr = `xab`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk1.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("asterisk1 valid case 3", async () => {
        const inputStr = `xaab`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk1.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("asterisk1 valid case 4", async () => {
        const inputStr = `710xab98`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk1.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });


    it("asterisk1 invalid case 1", async () => {
        const inputStr = `xaaa`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("asterisk1 invalid case 2", async () => {
        const inputStr = `aaabx`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit1.calculateWitness(circuitInputs);
        await circuit1.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });


    it("asterisk2 valid case 1", async () => {
        const inputStr = `aaa`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk2.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("asterisk2 valid case 2", async () => {
        const inputStr = `ab`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk2.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("asterisk2 valid case 3", async () => {
        const inputStr = `abbba`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk2.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });


    it("asterisk2 valid case 4", async () => {
        const inputStr = `717abb9`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk2.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("asterisk2 invalid case 1", async () => {
        const inputStr = `bbb`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("asterisk2 invalid case 2", async () => {
        const inputStr = `19bd7`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit2.calculateWitness(circuitInputs);
        await circuit2.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("asterisk3 valid case 1", async () => {
        const inputStr = `ab`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk3.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("asterisk3 valid case 2", async () => {
        const inputStr = `xaxxyxby`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/asterisk3.json"),
                "utf8"
            )
        )[0];
        for (let idx = 0; idx < 8; ++idx) {
            if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
                expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
            } else {
                expect(0n).toEqual(witness[2 + idx]);
            }
        }
    });

    it("asterisk3 invalid case 1", async () => {
        const inputStr = `axyxyyyx`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("asterisk3 invalid case 2", async () => {
        const inputStr = `xyyxxyba`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit3.calculateWitness(circuitInputs);
        await circuit3.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    // it("asterisk4 valid case 1", async () => {
    //     const inputStr = `b099`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit4.calculateWitness(circuitInputs);
    //     await circuit4.checkConstraints(witness);
    //     expect(1n).toEqual(witness[1]);
    //     const prefixIdxes = apis.extractSubstrIdxes(
    //         inputStr,
    //         readFileSync(
    //             path.join(__dirname, "./circuits/asterisk4.json"),
    //             "utf8"
    //         )
    //     )[0];
    //     for (let idx = 0; idx < 8; ++idx) {
    //         if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
    //             expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
    //         } else {
    //             expect(0n).toEqual(witness[2 + idx]);
    //         }
    //     }
    // });

    // it("asterisk4 invalid case 1", async () => {
    //     const inputStr = `192ue2iw`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit4.calculateWitness(circuitInputs);
    //     await circuit4.checkConstraints(witness);
    //     expect(0n).toEqual(witness[1]);
    //     for (let idx = 0; idx < 8; ++idx) {
    //         expect(0n).toEqual(witness[2 + idx]);
    //     }
    // });

    // it("asterisk5 valid case 1", async () => {
    //     const inputStr = `a`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit5.calculateWitness(circuitInputs);
    //     await circuit5.checkConstraints(witness);
    //     expect(1n).toEqual(witness[1]);
    //     const prefixIdxes = apis.extractSubstrIdxes(
    //         inputStr,
    //         readFileSync(
    //             path.join(__dirname, "./circuits/asterisk5.json"),
    //             "utf8"
    //         )
    //     )[0];
    //     for (let idx = 0; idx < 8; ++idx) {
    //         if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
    //             expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
    //         } else {
    //             expect(0n).toEqual(witness[2 + idx]);
    //         }
    //     }
    // });

    // it("asterisk5 valid case 2", async () => {
    //     const inputStr = `218aaaa2`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit5.calculateWitness(circuitInputs);
    //     await circuit5.checkConstraints(witness);
    //     expect(1n).toEqual(witness[1]);
    //     const prefixIdxes = apis.extractSubstrIdxes(
    //         inputStr,
    //         readFileSync(
    //             path.join(__dirname, "./circuits/asterisk5.json"),
    //             "utf8"
    //         )
    //     )[0];
    //     for (let idx = 0; idx < 8; ++idx) {
    //         if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
    //             expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
    //         } else {
    //             expect(0n).toEqual(witness[2 + idx]);
    //         }
    //     }
    // });

    // it("asterisk5 invalid case 1", async () => {
    //     const inputStr = `bbbbcccc`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit5.calculateWitness(circuitInputs);
    //     await circuit5.checkConstraints(witness);
    //     expect(0n).toEqual(witness[1]);
    //     for (let idx = 0; idx < 8; ++idx) {
    //         expect(0n).toEqual(witness[2 + idx]);
    //     }
    // });

    // it("asterisk6 valid case 1", async () => {
    //     const inputStr = ``;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit6.calculateWitness(circuitInputs);
    //     await circuit6.checkConstraints(witness);
    //     expect(1n).toEqual(witness[1]);
    //     const prefixIdxes = apis.extractSubstrIdxes(
    //         inputStr,
    //         readFileSync(
    //             path.join(__dirname, "./circuits/asterisk6.json"),
    //             "utf8"
    //         )
    //     )[0];
    //     for (let idx = 0; idx < 8; ++idx) {
    //         if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
    //             expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
    //         } else {
    //             expect(0n).toEqual(witness[2 + idx]);
    //         }
    //     }
    // });

    // it("asterisk6 valid case 2", async () => {
    //     const inputStr = `a`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit6.calculateWitness(circuitInputs);
    //     await circuit6.checkConstraints(witness);
    //     expect(1n).toEqual(witness[1]);
    //     const prefixIdxes = apis.extractSubstrIdxes(
    //         inputStr,
    //         readFileSync(
    //             path.join(__dirname, "./circuits/asterisk6.json"),
    //             "utf8"
    //         )
    //     )[0];
    //     for (let idx = 0; idx < 8; ++idx) {
    //         if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
    //             expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
    //         } else {
    //             expect(0n).toEqual(witness[2 + idx]);
    //         }
    //     }
    // });

    // it("asterisk6 valid case 3", async () => {
    //     const inputStr = `1921 abw`;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit6.calculateWitness(circuitInputs);
    //     await circuit6.checkConstraints(witness);
    //     expect(1n).toEqual(witness[1]);
    //     const prefixIdxes = apis.extractSubstrIdxes(
    //         inputStr,
    //         readFileSync(
    //             path.join(__dirname, "./circuits/asterisk6.json"),
    //             "utf8"
    //         )
    //     )[0];
    //     for (let idx = 0; idx < 8; ++idx) {
    //         if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
    //             expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
    //         } else {
    //             expect(0n).toEqual(witness[2 + idx]);
    //         }
    //     }
    // });

    
});
