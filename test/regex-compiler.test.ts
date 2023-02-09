import { expect } from 'chai';
const path = require('path')
const circom_tester = require('circom_tester');
const generator = require('../compiler/gen')
const wasm_tester = circom_tester.wasm;

describe("regex compiler tests", function () {
    //TOFIX regex discrepancy in group ()

    const padded_email_body = `padded email was meant for @katat body padded email was meant for @katat body`;
    let in_body_padded = padded_email_body.split('').map((x: any) => x.charCodeAt(0))
    while (in_body_padded.length < 1536) {
        in_body_padded.push(0);
    }
    in_body_padded = in_body_padded.map((x: any) => `${x}`);

    [
        [
            '1st match in the middle', 
            [`email was meant for @(${generator.word_char}+)`, 1],
            (signals: any) => {
                const expected_reveal = 'katat'.split('').map((x: any) => BigInt(x.charCodeAt(0)))
                assert_reveal(signals, expected_reveal);
                expect(signals.main.out).to.equal(2n)
                expect(signals.main.start_idx).to.equal(28n)
            }
        ],
        [
            '2nd match in the middle', 
            [`email was meant for @(${generator.word_char}+)`, 2],
            (signals: any) => {
                const expected_reveal = 'katat'.split('').map((x: any) => BigInt(x.charCodeAt(0)))
                assert_reveal(signals, expected_reveal);
                expect(signals.main.out).to.equal(2n)
                expect(signals.main.start_idx).to.equal(67n)
            }
        ],
    ].forEach((test) => {
        //@ts-ignore
        const name: string = test[0]
        //@ts-ignore
        const regex: string = test[1][0]
        //@ts-ignore
        const match_idx: number = test[1][1]
        //@ts-ignore
        const checkSignals: Function = test[2]

        describe(name, () => {
            let circuit: any;
            before(async function () {
                await generator.generateCircuit(
                    regex, 
                    '../circuits'
                )
                circuit = await wasm_tester(
                    path.join(__dirname, "circuits", "test_regex_compiler.circom"),
                    {recompile: true, output: `${__dirname}/../build/`, O: 0}
                );
            });
        
            it('checks witness', async function() {
                let witness = await circuit.calculateWitness({msg: in_body_padded, match_idx});
                const signals = await circuit.getJSONOutput('main', witness);
                checkSignals(signals)
                await circuit.checkConstraints(witness);
            });
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

function assert_reveal(signals: any, expected_reveal: bigint[]) {
    for (let m in signals.main.reveal_shifted) {
        const value = signals.main.reveal_shifted[m];
        if (expected_reveal[m as any]) {
            expect(value).to.equal(expected_reveal[m as any]);
        }
    }
}
