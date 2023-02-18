const generator = require('../compiler/gen')

const program = require("commander");

program
    .version("0.0.1")
    .description("A sample CLI program")

program
    .command("compile <regex> <circuit_name>")
    .description("Compile a regular expression into circom circuits")
    .action((regex, circuit_name) => {
        regex = regex
            .replace(/\\n/g, "\n")
            .replace(/\\r/g, "\r")
            .replace(/\\x80/g, "\x80")

        generator.generateCircuit(regex, undefined, circuit_name)
    });

program.on("command:*", () => {
    console.error(
        "Error: Invalid command. See --help for a list of available commands."
    );
    process.exit(1);
});

program.parse(process.argv);

if (!program.args.length) {
    program.help();
}
