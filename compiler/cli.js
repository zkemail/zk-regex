const generator = require('../compiler/gen');

const program = require('commander');
const unescapeJs = require('unescape-js');

program.version('0.0.1')
    .description('A sample CLI program');

program.command('compile <regex> <circuit_name>')
    .description('Compile a regular expression into circom circuits')
    .action((regex, circuit_name) => {
        regex = unescapeJs(regex);
        generator.generateCircuit(regex, undefined, circuit_name);
    });

program.on('command:*', () => {
    console.error(
        'Error: Invalid command. See --help for a list of available commands.'
    );
    process.exit(1);
});

program.parse(process.argv);

if (!process.args.length) {
    program.help();
}
