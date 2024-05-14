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
describe("Plus Regex", () => {
    let circuit1;
    let circuit2;
    let circuit3;
    let circuit4;
    // let circuit5;
    // let circuit6;
    beforeAll(async () => {
        writeFileSync(
            path.join(__dirname, "./circuits/plus1_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/plus1.json"),
                    "utf8"
                ),
                "Plus1Regex"
            )
        );
        circuit1 = await wasm_tester(
            path.join(__dirname, "./circuits/test_plus1_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/plus2_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/plus2.json"),
                    "utf8"
                ),
                "Plus2Regex"
            )
        );
        circuit2 = await wasm_tester(
            path.join(__dirname, "./circuits/test_plus2_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/plus3_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/plus3.json"),
                    "utf8"
                ),
                "Plus3Regex"
            )
        );
        circuit3 = await wasm_tester(
            path.join(__dirname, "./circuits/test_plus3_regex.circom"),
            option
        );

        writeFileSync(
            path.join(__dirname, "./circuits/plus4_regex.circom"),
            compiler.genFromDecomposed(
                readFileSync(
                    path.join(__dirname, "./circuits/plus4.json"),
                    "utf8"
                ),
                "Plus4Regex"
            )
        );
        circuit4 = await wasm_tester(
            path.join(__dirname, "./circuits/test_plus4_regex.circom"),
            option
        );

        // writeFileSync(
        //     path.join(__dirname, "./circuits/plus5_regex.circom"),
        //     compiler.genFromDecomposed(
        //         readFileSync(
        //             path.join(__dirname, "./circuits/plus5.json"),
        //             "utf8"
        //         ),
        //         "Plus5Regex"
        //     )
        // );
        // circuit5 = await wasm_tester(
        //     path.join(__dirname, "./circuits/test_plus5_regex.circom"),
        //     option
        // );

        // writeFileSync(
        //     path.join(__dirname, "./circuits/plus6_regex.circom"),
        //     compiler.genFromDecomposed(
        //         readFileSync(
        //             path.join(__dirname, "./circuits/plus6.json"),
        //             "utf8"
        //         ),
        //         "Plus6Regex"
        //     )
        // );
        // circuit6 = await wasm_tester(
        //     path.join(__dirname, "./circuits/test_plus6_regex.circom"),
        //     option
        // );
    });

    it("plus1 valid case 1", async () => {
        const inputStr = `ab`;
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
                path.join(__dirname, "./circuits/plus1.json"),
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


    it("plus1 valid case 2", async () => {
        const inputStr = `aaaab`;
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
                path.join(__dirname, "./circuits/plus1.json"),
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

    it("plus1 valid case 3", async () => {
        const inputStr = `7aab89ac`;
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
                path.join(__dirname, "./circuits/plus1.json"),
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

    it("plus1 invalid case 1", async () => {
        const inputStr = `b`;
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

    it("plus1 invalid case 2", async () => {
        const inputStr = `aacaadae`;
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

    it("plus1 invalid case 3", async () => {
        const inputStr = `aaaaaaaa`;
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

    it("plus2 valid case 1", async () => {
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
                path.join(__dirname, "./circuits/plus2.json"),
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

    it("plus2 valid case 2", async () => {
        const inputStr = `ac`;
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
                path.join(__dirname, "./circuits/plus2.json"),
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

    it("plus2 valid case 3", async () => {
        const inputStr = `abccbbcc`;
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
                path.join(__dirname, "./circuits/plus2.json"),
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

    it("plus2 valid case 4", async () => {
        const inputStr = `7abbcaa`;
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
                path.join(__dirname, "./circuits/plus2.json"),
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

    it("plus2 invalid case 1", async () => {
        const inputStr = `adefghij`;
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

    it("plus3 valid case 1", async () => {
        const inputStr = `abcbcbc`;
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
                path.join(__dirname, "./circuits/plus3.json"),
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

    it("plus3 valid case 2", async () => {
        const inputStr = `acbabcbc`;
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
                path.join(__dirname, "./circuits/plus3.json"),
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

    it("plus3 valid case 3", async () => {
        const inputStr = `abccbcbb`;
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
                path.join(__dirname, "./circuits/plus3.json"),
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

    it("plus3 invalid case 1", async () => {
        const inputStr = `abab`;
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

    it("plus4 valid case 1", async () => {
        const inputStr = `1234512b`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/plus4.json"),
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

    it("plus4 valid case 2", async () => {
        const inputStr = `2134512b`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(1n).toEqual(witness[1]);
        const prefixIdxes = apis.extractSubstrIdxes(
            inputStr,
            readFileSync(
                path.join(__dirname, "./circuits/plus4.json"),
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

    it("plus4 invalid case 1", async () => {
        const inputStr = `1234b`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    it("plus4 invalid case 2", async () => {
        const inputStr = `34512`;
        const paddedStr = apis.padString(inputStr, 8);
        const circuitInputs = {
            msg: paddedStr,
        };
        const witness = await circuit4.calculateWitness(circuitInputs);
        await circuit4.checkConstraints(witness);
        expect(0n).toEqual(witness[1]);
        for (let idx = 0; idx < 8; ++idx) {
            expect(0n).toEqual(witness[2 + idx]);
        }
    });

    // it("plus5 valid case 1", async () => {
    //     const inputStr = `aa`;
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
    //             path.join(__dirname, "./circuits/plus5.json"),
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

    // it("plus5 valid case 2", async () => {
    //     const inputStr = `aaaababb`;
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
    //             path.join(__dirname, "./circuits/plus5.json"),
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

    // it("plus5 valid case 3", async () => {
    //     const inputStr = `bbcw2cab`;
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
    //             path.join(__dirname, "./circuits/plus5.json"),
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

    // it("plus5 invalid case 1", async () => {
    //     const inputStr = `872jdiua`;
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

    // it("plus5 invalid case 2", async () => {
    //     const inputStr = `872jdiu7`;
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


    // it("plus6 valid case 1", async () => {
    //     const inputStr = `aaaabbbb`;
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
    //             path.join(__dirname, "./circuits/plus6.json"),
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

    // it("plus6 invalid case 1", async () => {
    //     const inputStr = ``;
    //     const paddedStr = apis.padString(inputStr, 8);
    //     const circuitInputs = {
    //         msg: paddedStr,
    //     };
    //     const witness = await circuit6.calculateWitness(circuitInputs);
    //     await circuit6.checkConstraints(witness);
    //     expect(0n).toEqual(witness[1]);
    //     for (let idx = 0; idx < 8; ++idx) {
    //         expect(0n).toEqual(witness[2 + idx]);
    //     }
    // });
});
