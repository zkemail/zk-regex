import { expect } from 'chai';
const path = require('path')
const circom_tester = require('circom_tester');
const generator = require('../compiler/gen')
const wasm_tester = circom_tester.wasm;

describe("regex compiler tests", function () {
    [
        [
            [`1=(a|b) (2=(b|c)+ )+d`, 0],
            [
                [
                    '1 entire match and 1st sub-group match',
                    convertMsg(`1=a 2=b 2=bc 2=c d`),
                    0,
                    (signals: any) => {
                        expect(signals.main.entire_count).to.equal(1n)
                        expect(signals.main.group_match_count).to.equal(1n)
                        expect(signals.main.start_idx).to.equal(2n)
                        const expected_reveal = encodeString('a')
                        assert_reveal(signals, expected_reveal);
                    }
                ],
            ]
        ],
        [
            [`1=(a|b) (2=(b|c)+ )+d`, 1],
            [
                [
                    '1 entire match and 1st sub-group match',
                    convertMsg(`1=a 2=b 2=bc 2=c d`),
                    0,
                    (signals: any) => {
                        expect(signals.main.entire_count).to.equal(1n)
                        expect(signals.main.group_match_count).to.equal(3n)
                        expect(signals.main.start_idx).to.equal(6n)
                        const expected_reveal = encodeString('b')
                        assert_reveal(signals, expected_reveal);
                    }
                ],
                [
                    '1 entire match and 2nd sub-group match',
                    convertMsg(`1=a 2=b 2=bc 2=c d`),
                    1,
                    (signals: any) => {
                        expect(signals.main.entire_count).to.equal(1n)
                        expect(signals.main.group_match_count).to.equal(3n)
                        expect(signals.main.start_idx).to.equal(10n)
                        const expected_reveal = encodeString('bc')
                        assert_reveal(signals, expected_reveal);
                    }
                ],
                [
                    '1 entire match and 3rd sub-group match',
                    convertMsg(`1=a 2=b 2=bc 2=c d`),
                    2,
                    (signals: any) => {
                        expect(signals.main.entire_count).to.equal(1n)
                        expect(signals.main.group_match_count).to.equal(3n)
                        expect(signals.main.start_idx).to.equal(15n)
                        const expected_reveal = encodeString('c')
                        assert_reveal(signals, expected_reveal);
                    }
                ],
                [
                    '0 entire match and 2 group matches',
                    convertMsg(`1=a 2=b 2=bc 2=e d`),
                    1,
                    (signals: any) => {
                        expect(signals.main.entire_count).to.equal(0n)
                        expect(signals.main.group_match_count).to.equal(2n)
                    }
                ],
                [
                    '2 entire match and 2nd sub-group match',
                    convertMsg(`1=a 2=b 2=bc 2=c da 1=a 2=cb 2=c 2=b dd`),
                    1,
                    (signals: any) => {
                        expect(signals.main.entire_count).to.equal(2n)
                        expect(signals.main.group_match_count).to.equal(6n)
                        expect(signals.main.start_idx).to.equal(10n)
                        const expected_reveal = encodeString('bc')
                        assert_reveal(signals, expected_reveal);
                    }
                ],
                // todo TOFIX
                // [
                //     '1 entire match and 1+ group matches with no trails behind the last group',
                //     convertMsg(`1=a 2=b 2=bc 2=c `),
                //     [`1=(a|b) (2=(b|c)+ )+`, 1, 1],
                //     (signals: any) => {
                //         for (let i = 0; i < signals.main.states.length; i++) {
                //             console.log(signals.main.states[i][8])
                //         }
                //         expect(signals.main.entire_count).to.equal(1n)
                //         expect(signals.main.group_match_count).to.equal(3n)
                //         expect(signals.main.start_idx).to.equal(10n)
                //         const expected_reveal = 'bc'.split('').map((x: any) => BigInt(x.charCodeAt(0)))
                //         assert_reveal(signals, expected_reveal);
                //     }
                // ],
                // [
                //     'assert body hash', 
                //     email_inputs.in_padded,
                //     ['\r\n' +
                //     'dkim-signature:((a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z)=(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|!|"|#|$|%|&|\'|\\(|\\)|\\*|\\+|,|-|.|/|:|<|=|>|\\?|@|[|\\\\|]|^|_|`|{|\\||}|~| |\t|\n' +
                //     '|\r|\x0B|\f)+; )+bh=(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|\\+|/|=)+; ', 1],
                //     // ['3(d|e|f)+ 1(a|b) 2(b|c)+ ', 1],
                //     (signals: any) => {
                //         // const expected_reveal = 'katat'.split('').map((x: any) => BigInt(x.charCodeAt(0)))
                //         // assert_reveal(signals, expected_reveal);
                //         for (let i = 0; i < signals.main.states.length; i++) {
                //             // console.log(signals.main.states[i][26])
                //             // console.log(signals.main.states[i][1])
                //             console.log(signals.main.states[i][28])
                //         }
                //         // console.log(JSON.stringify(signals.main.reveal, undefined, 2))
                //         expect(signals.main.entire_count).to.equal(1n)
                //         // expect(signals.main.group_match_count).to.equal(1n)
                //         // expect(signals.main.start_idx).to.equal(67n)
                //     }
                // ],
            ]
        ],
    ]
    .forEach((regexSuite: any) => {
        const regex = regexSuite[0][0]
        const group_idx = regexSuite[0][1]
        const tests: any = regexSuite[1]

        const testCircomFile = `test_regex_compiler_group_${group_idx}.circom`
        let circuit: any;
        describe(`/${regex}/ > group idx: ${group_idx} > ${testCircomFile}`, () => {
            before(async function () {
                await generator.generateCircuit(
                    regex, 
                    '../circuits'
                )
                circuit = await wasm_tester(
                    path.join(__dirname, "circuits", testCircomFile),
                    {recompile: process.env.NO_COMPILE ? false : true, output: `${__dirname}/../build/`, O: 0}
                );
            });
            tests.forEach((test: any) => {
                //@ts-ignore
                const name: string = test[0]
                //@ts-ignore
                const content: string = test[1]
                //@ts-ignore
                const match_idx: number = test[2]
                //@ts-ignore
                const checkSignals: Function = test[3]
        
                describe(name, () => {
                    it('checks witness', async function() {
                        let witness = await circuit.calculateWitness({msg: content, match_idx});
                        const signals = await circuit.getJSONOutput('main', witness);
                        checkSignals(signals)
                        await circuit.checkConstraints(witness);
                    });
                });
            })
        });
    })

    describe('exceptions', () => {
        it('character class not supported', async () => {
            try {
                await generator.generateCircuit(
                    '[a-z]',
                    '../circuits'
                )
            }
            catch (e: any) {
                expect(e.message).to.equal('CharacterClass not supported')
                return
            }

            expect.fail('should have thrown')
        });
    });
});

function encodeString(str: string) {
    return str.split('').map((x: any) => BigInt(x.charCodeAt(0)));
}

function convertMsg(msg: string, maxLen: number = 1536) {
    let msgEncoded = msg.split('').map((x: any) => x.charCodeAt(0));
    while (msgEncoded.length < maxLen) {
        msgEncoded.push(0);
    }
    msgEncoded = msgEncoded.map((x: any) => `${x}`);
    return msgEncoded;
}

function assert_reveal(signals: any, expected_reveal: bigint[]) {
    for (let m in signals.main.reveal_shifted) {
        const value = signals.main.reveal_shifted[m];
        if (expected_reveal[m as any]) {
            expect(value).to.equal(expected_reveal[m as any]);
        }
    }
}
