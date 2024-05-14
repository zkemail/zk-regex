// import circom_tester from "circom_tester";
// import * as path from "path";
// import { readFileSync, writeFileSync } from "fs";
// import apis from "../../apis/pkg";
// import compiler from "../../compiler/pkg";
// const option = {
//   include: path.join(__dirname, "../../../node_modules"),
// };
// const wasm_tester = circom_tester.wasm;

// jest.setTimeout(600000);
// describe("Multi Accept Regex", () => {
//     let circuit1;
//     let circuit2;
//     let circuit3;
//     let circuit4;
//     let circuit5;
//     beforeAll(async () => {
//         writeFileSync(
//             path.join(__dirname, "./circuits/multi_accept1_regex.circom"),
//             compiler.genFromDecomposed(
//                 readFileSync(
//                     path.join(__dirname, "./circuits/multi_accept1.json"),
//                     "utf8"
//                 ),
//                 "MultiAccept1Regex"
//             )
//         );
//         circuit1 = await wasm_tester(
//             path.join(__dirname, "./circuits/test_multi_accept1_regex.circom"),
//             option
//         );

//         writeFileSync(
//             path.join(__dirname, "./circuits/multi_accept2_regex.circom"),
//             compiler.genFromDecomposed(
//                 readFileSync(
//                     path.join(__dirname, "./circuits/multi_accept2.json"),
//                     "utf8"
//                 ),
//                 "MultiAccept2Regex"
//             )
//         );
//         circuit2 = await wasm_tester(
//             path.join(__dirname, "./circuits/test_multi_accept2_regex.circom"),
//             option
//         );

//         writeFileSync(
//             path.join(__dirname, "./circuits/multi_accept3_regex.circom"),
//             compiler.genFromDecomposed(
//                 readFileSync(
//                     path.join(__dirname, "./circuits/multi_accept3.json"),
//                     "utf8"
//                 ),
//                 "MultiAccept3Regex"
//             )
//         );
//         circuit3 = await wasm_tester(
//             path.join(__dirname, "./circuits/test_multi_accept3_regex.circom"),
//             option
//         );

//         writeFileSync(
//             path.join(__dirname, "./circuits/multi_accept4_regex.circom"),
//             compiler.genFromDecomposed(
//                 readFileSync(
//                     path.join(__dirname, "./circuits/multi_accept4.json"),
//                     "utf8"
//                 ),
//                 "MultiAccept4Regex"
//             )
//         );
//         circuit4 = await wasm_tester(
//             path.join(__dirname, "./circuits/test_multi_accept4_regex.circom"),
//             option
//         );

//         writeFileSync(
//             path.join(__dirname, "./circuits/multi_accept5_regex.circom"),
//             compiler.genFromDecomposed(
//                 readFileSync(
//                     path.join(__dirname, "./circuits/multi_accept5.json"),
//                     "utf8"
//                 ),
//                 "MultiAccept5Regex"
//             )
//         );
//         circuit5 = await wasm_tester(
//             path.join(__dirname, "./circuits/test_multi_accept5_regex.circom"),
//             option
//         );
//     });

//     it("multi accept1 valid case 1", async () => {
//         const inputStr = `ab`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit1.calculateWitness(circuitInputs);
//         await circuit1.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept1.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept1 valid case 2", async () => {
//         const inputStr = `81acdj`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit1.calculateWitness(circuitInputs);
//         await circuit1.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept1.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept1 invalid case 1", async () => {
//         const inputStr = `aaaa8l9a`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit1.calculateWitness(circuitInputs);
//         await circuit1.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept1 invalid case 2", async () => {
//         const inputStr = `babcabc`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit1.calculateWitness(circuitInputs);
//         await circuit1.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept2 valid case 1", async () => {
//         const inputStr = `810a0qoi`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit2.calculateWitness(circuitInputs);
//         await circuit2.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept2.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept2 valid case 2", async () => {
//         const inputStr = `81abccb9`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit2.calculateWitness(circuitInputs);
//         await circuit2.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept2.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept2 invalid case 1", async () => {
//         const inputStr = `aaaa71lp`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit2.calculateWitness(circuitInputs);
//         await circuit2.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept2 invalid case 2", async () => {
//         const inputStr = `bccbaaaj`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit2.calculateWitness(circuitInputs);
//         await circuit2.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept3 valid case 1", async () => {
//         const inputStr = `81abccb9`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit3.calculateWitness(circuitInputs);
//         await circuit3.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept3.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept3 invalid case 1", async () => {
//         const inputStr = `aaaa71lp`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit3.calculateWitness(circuitInputs);
//         await circuit3.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept3 invalid case 2", async () => {
//         const inputStr = `71bcc6a8`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit3.calculateWitness(circuitInputs);
//         await circuit3.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept4 valid case 1", async () => {
//         const inputStr = `adegabc8`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit4.calculateWitness(circuitInputs);
//         await circuit4.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept4.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept4 valid case 2", async () => {
//         const inputStr = `adeccc8j`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit4.calculateWitness(circuitInputs);
//         await circuit4.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept4.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept4 valid case 3", async () => {
//         const inputStr = `78accdce`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit4.calculateWitness(circuitInputs);
//         await circuit4.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept4.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept4 invalid case 1", async () => {
//         const inputStr = `81abccde`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit4.calculateWitness(circuitInputs);
//         await circuit4.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept4 invalid case 2", async () => {
//         const inputStr = `a`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit4.calculateWitness(circuitInputs);
//         await circuit4.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept5 valid case 1", async () => {
//         const inputStr = `adecddec`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit5.calculateWitness(circuitInputs);
//         await circuit5.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept5.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept5 valid case 2", async () => {
//         const inputStr = `71\nadcec`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit5.calculateWitness(circuitInputs);
//         await circuit5.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         const prefixIdxes = apis.extractSubstrIdxes(
//             inputStr,
//             readFileSync(
//                 path.join(__dirname, "../circuits/common/multi_accept5.json"),
//                 "utf8"
//             )
//         )[0];
//         for (let idx = 0; idx < 8; ++idx) {
//             if (idx >= prefixIdxes[0] && idx < prefixIdxes[1]) {
//                 expect(BigInt(paddedStr[idx])).toEqual(witness[2 + idx]);
//             } else {
//                 expect(0n).toEqual(witness[2 + idx]);
//             }
//         }
//     });

//     it("multi accept5 invalid case 1", async () => {
//         const inputStr = `aaccedcd`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit5.calculateWitness(circuitInputs);
//         await circuit5.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept5 invalid case 2", async () => {
//         const inputStr = `a`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit5.calculateWitness(circuitInputs);
//         await circuit5.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }
//     });

//     it("multi accept5 invalid case 3", async () => {
//         const inputStr = `71nadcec`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit5.calculateWitness(circuitInputs);
//         await circuit5.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }        
//     });

//     it("multi accept5 invalid case 4", async () => {
//         const inputStr = `71naadce`;
//         const paddedStr = apis.padString(inputStr, 8);
//         const circuitInputs = {
//             msg: paddedStr,
//         };
//         const witness = await circuit5.calculateWitness(circuitInputs);
//         await circuit5.checkConstraints(witness);
//         expect(1n).toEqual(witness[1]);
//         for (let idx = 0; idx < 8; ++idx) {
//             expect(0n).toEqual(witness[2 + idx]);
//         }        
//     });
// });
