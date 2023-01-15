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
            'matches in the middle', 
            `email was meant for @(${generator.word_char}+)`,
            (signals: any) => {
                console.log(signals.main.states_count)
                for (let i = 28; i <= 32; i++) {
                    expect(signals.main.states_count[i]).to.equal(1n)
                }
                for (let i = 67; i <= 71; i++) {
                    expect(signals.main.states_count[i]).to.equal(2n)
                }
                expect(signals.main.out).to.equal(2n)
            }
        ],
        [
            'match at the beginning',
            `(${generator.word_char}+) email was meant`,
            (signals: any) => {
                for (let i = 0; i < 6; i++) {
                    expect(signals.main.states_count[i]).to.equal(1n)
                }
                // for (let i = 67; i <= 71; i++) {
                //     expect(signals.main.states_count[i]).to.equal(2n)
                // }
                expect(signals.main.out).to.equal(2n)
            }
        ],
    ].forEach((test) => {
        //@ts-ignore
        const name: string = test[0]
        //@ts-ignore
        const regex: string = test[1]
        //@ts-ignore
        const checkSignals: Function = test[2]

        describe(name, () => {
            let circuit: any;
            before(async function () {
                await generator.generateCircuit(regex, '../../circuits')
                circuit = await wasm_tester(
                    path.join(__dirname, "circuits", "test_regex_compiler.circom"),
                    {recompile: true, output: `${__dirname}/../build/`}
                );
            });
        
            it('checks witness', async function() {
                let witness = await circuit.calculateWitness({msg: in_body_padded});
                const signals = await circuit.getJSONOutput('main', witness);
                checkSignals(signals)
                await circuit.checkConstraints(witness);
            });
        });
    })
});