import { expect } from 'chai';
const path = require('path')
const circom_tester = require('circom_tester');
const generator = require('../compiler/gen')
const wasm_tester = circom_tester.wasm;

describe("regex compiler tests", function () {
    // runs circom compilation
    let circuit: any;
    before(async function () {
        let regex = `email was meant for @${generator.word_char}+`;
        await generator.generateCircuit(regex, '../../circuits')
        circuit = await wasm_tester(
            path.join(__dirname, "circuits", "test_regex_compiler.circom"),
            {recompile: true, output: `${__dirname}/../build/`}
        );
    });


    const padded_email_body = `padded email was meant for @katat body padded email was meant for @katat body`;
    let in_body_padded = padded_email_body.split('').map((x: any) => x.charCodeAt(0))
    while (in_body_padded.length < 1536) {
        in_body_padded.push(0);
    }
    in_body_padded = in_body_padded.map((x: any) => `${x}`);

    it('search twitter account', async function() {
        let witness = await circuit.calculateWitness({msg: in_body_padded});
        const signals = await circuit.getJSONOutput('main', witness);
        for (let i = 29; i <= 33; i++) {
            expect(signals.main.states_count[i]).to.equal(1n)
        }
        for (let i = 68; i <= 72; i++) {
            expect(signals.main.states_count[i]).to.equal(2n)
        }
        expect(signals.main.out).to.equal(2n)
        await circuit.checkConstraints(witness);
    });

});