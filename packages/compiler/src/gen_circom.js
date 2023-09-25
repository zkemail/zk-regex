function genCircomAllstr(graph_json, template_name) {
    const N = graph_json.length;
    // const graph = Array(N).fill({});
    const rev_graph = [];
    const to_init_graph = [];
    let init_going_state = null;
    for (let i = 0; i < N; i++) {
        rev_graph.push({});
        to_init_graph.push([]);
    }
    let accept_nodes = new Set();
    for (let i = 0; i < N; i++) {
        for (let k in graph_json[i]["edges"]) {
            const v = graph_json[i]["edges"][k];
            rev_graph[v][i] = Array.from(JSON.parse(k)).map(c => c.charCodeAt());
            if (i == 0) {
                const index = rev_graph[v][i].indexOf(94);
                if (index != -1) {
                    init_going_state = v;
                    rev_graph[v][i][index] = 128;
                }
                for (let j = 0; j < rev_graph[v][i].length; j++) {
                    if (rev_graph[v][i][j] == 128) {
                        continue;
                    }
                    to_init_graph[v].push(rev_graph[v][i][j]);
                }
            }
        }
        if (graph_json[i]["type"] == "accept") {
            accept_nodes.add(i);
        }
    }
    if (init_going_state != null) {
        for (const [going_state, chars] of Object.entries(to_init_graph)) {
            if (chars.length == 0) {
                continue;
            }
            if (rev_graph[going_state][init_going_state] == null) {
                rev_graph[going_state][init_going_state] = [];
            }
            rev_graph[going_state][init_going_state] = rev_graph[going_state][init_going_state].concat(chars);
        }
    }

    if (accept_nodes[0] != null) {
        throw new Error("accept node must not be 0");
    }
    accept_nodes = [...accept_nodes];
    if (accept_nodes.length != 1) {
        throw new Error("the size of accept nodes must be one");
    }

    let eq_i = 0;
    let lt_i = 0;
    let and_i = 0;
    let multi_or_i = 0;

    let lines = [];
    lines.push("\tfor (var i = 0; i < num_bytes; i++) {");

    const uppercase = new Set(Array.from("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(c => c.charCodeAt()));
    const lowercase = new Set(Array.from("abcdefghijklmnopqrstuvwxyz").map(c => c.charCodeAt()));
    const digits = new Set(Array.from("0123456789").map(c => c.charCodeAt()));
    const symbols1 = new Set([":", ";", "<", "=", ">", "?", "@"].map(c => c.charCodeAt()));
    const symbols2 = new Set(["[", "\\", "]", "^", "_", "`"].map(c => c.charCodeAt()));
    const symbols3 = new Set(["{", "|", "}", "~"].map(c => c.charCodeAt()));
    lines.push(`\t\tstate_changed[i] = MultiOR(${N - 1});`);
    for (let i = 1; i < N; i++) {
        const outputs = [];
        for (let prev_i of Object.keys(rev_graph[i])) {
            const k = rev_graph[i][prev_i];
            const eq_outputs = [];
            const vals = new Set(k);
            if (vals.size == 0) {
                continue;
            }
            const min_maxs = [];
            for (let subsets of [
                [digits, 47, 58],
                [symbols1, 57, 65],
                [uppercase, 64, 91],
                [symbols2, 90, 97],
                [lowercase, 96, 123],
                [symbols3, 122, 127]
            ]) {
                const subset = subsets[0];
                const min = subsets[1];
                const max = subsets[2];
                if (vals.isSuperset(subset)) {
                    vals.difference(subset);
                    if (min_maxs.length == 0) {
                        min_maxs.push([min, max]);
                    } else {
                        const last = min_maxs[min_maxs.length - 1];
                        if (last[1] - 1 == min) {
                            min_maxs[min_maxs.length - 1][1] = max;
                        } else {
                            min_maxs.push([min, max]);
                        }
                    }
                }
            }

            for (let min_max of min_maxs) {
                lines.push(`\t\tlt[${lt_i}][i] = LessThan(8);`);
                lines.push(`\t\tlt[${lt_i}][i].in[0] <== ${min_max[0]};`);
                lines.push(`\t\tlt[${lt_i}][i].in[1] <== in[i];`);

                lines.push(`\t\tlt[${lt_i + 1}][i] = LessThan(8);`);
                lines.push(`\t\tlt[${lt_i + 1}][i].in[0] <== in[i];`);
                lines.push(`\t\tlt[${lt_i + 1}][i].in[1] <== ${min_max[1]};`);

                lines.push(`\t\tand[${and_i}][i] = AND();`);
                lines.push(`\t\tand[${and_i}][i].a <== lt[${lt_i}][i].out;`);
                lines.push(`\t\tand[${and_i}][i].b <== lt[${lt_i + 1}][i].out;`);

                eq_outputs.push(['and', and_i]);
                lt_i += 2
                and_i += 1
            }

            for (let code of vals) {
                lines.push(`\t\teq[${eq_i}][i] = IsEqual();`);
                lines.push(`\t\teq[${eq_i}][i].in[0] <== in[i];`);
                lines.push(`\t\teq[${eq_i}][i].in[1] <== ${code};`);
                eq_outputs.push(['eq', eq_i]);
                eq_i += 1
            }

            lines.push(`\t\tand[${and_i}][i] = AND();`);
            lines.push(`\t\tand[${and_i}][i].a <== states[i][${prev_i}];`);
            if (eq_outputs.length == 1) {
                lines.push(`\t\tand[${and_i}][i].b <== ${eq_outputs[0][0]}[${eq_outputs[0][1]}][i].out;`);
            } else if (eq_outputs.length > 1) {
                lines.push(`\t\tmulti_or[${multi_or_i}][i] = MultiOR(${eq_outputs.length});`);
                for (let output_i = 0; output_i < eq_outputs.length; output_i++) {
                    lines.push(`\t\tmulti_or[${multi_or_i}][i].in[${output_i}] <== ${eq_outputs[output_i][0]}[${eq_outputs[output_i][1]}][i].out;`);
                }
                lines.push(`\t\tand[${and_i}][i].b <== multi_or[${multi_or_i}][i].out;`);
                multi_or_i += 1
            }

            outputs.push(and_i);
            and_i += 1;
        }

        if (outputs.length == 1) {
            lines.push(`\t\tstates[i+1][${i}] <== and[${outputs[0]}][i].out;`);
        } else if (outputs.length > 1) {
            lines.push(`\t\tmulti_or[${multi_or_i}][i] = MultiOR(${outputs.length});`);
            for (let output_i = 0; output_i < outputs.length; output_i++) {
                lines.push(`\t\tmulti_or[${multi_or_i}][i].in[${output_i}] <== and[${outputs[output_i]}][i].out;`);
            }
            lines.push(`\t\tstates[i+1][${i}] <== multi_or[${multi_or_i}][i].out;`);
            multi_or_i += 1
        }
        lines.push(`\t\tstate_changed[i].in[${i - 1}] <== states[i+1][${i}];`);
    }
    lines.push(`\t\tstates[i+1][0] <== 1 - state_changed[i].out;`);
    lines.push("\t}");


    const declarations = [];
    declarations.push(`pragma circom 2.1.5;\n`);
    declarations.push(`include "zk-regex-circom/circuits/regex_helpers.circom";\n`);
    // declarations.push(`pragma circom 2.1.5;\ninclude "@zk-email/circuits/regexes/regex_helpers.circom";\n`);
    declarations.push(`template ${template_name}(msg_bytes) {`);
    declarations.push(`\tsignal input msg[msg_bytes];`);
    declarations.push(`\tsignal output out;\n`);
    declarations.push(`\tvar num_bytes = msg_bytes+1;`);
    declarations.push(`\tsignal in[num_bytes];`);
    declarations.push(`\tin[0]<==128;`);
    declarations.push(`\tfor (var i = 0; i < msg_bytes; i++) {`);
    declarations.push(`\t\tin[i+1] <== msg[i];`);
    declarations.push(`\t}\n`);
    if (eq_i > 0) {
        declarations.push(`\tcomponent eq[${eq_i}][num_bytes];`);
    }
    if (lt_i > 0) {
        declarations.push(`\tcomponent lt[${lt_i}][num_bytes];`);
    }
    if (and_i > 0) {
        declarations.push(`\tcomponent and[${and_i}][num_bytes];`);
    }
    if (multi_or_i > 0) {
        declarations.push(`\tcomponent multi_or[${multi_or_i}][num_bytes];`);
    }
    declarations.push(`\tsignal states[num_bytes+1][${N}];`);
    declarations.push(`\tcomponent state_changed[num_bytes];`);
    declarations.push("");

    const init_code = [];
    init_code.push(`\tstates[0][0] <== 1;`);
    init_code.push(`\tfor (var i = 1; i < ${N}; i++) {`);
    init_code.push(`\t\tstates[0][i] <== 0;`);
    init_code.push("\t}");
    init_code.push("");

    lines = declarations.concat(init_code).concat(lines);

    const accept_node = accept_nodes[0];
    const accept_lines = [""];
    accept_lines.push("\tcomponent final_state_result = MultiOR(num_bytes+1);");
    accept_lines.push("\tfor (var i = 0; i <= num_bytes; i++) {");
    accept_lines.push(`\t\tfinal_state_result.in[i] <== states[i][${accept_node}];`);
    accept_lines.push("\t}");
    accept_lines.push("\tout <== final_state_result.out;");

    lines = lines.concat(accept_lines);
    let string = lines.reduce((res, line) => res + line + "\n", "");
    return string;
}



Set.prototype.isSuperset = function (subset) {
    if (this.size == 0) {
        return false;
    }
    for (var elem of subset) {
        if (!this.has(elem)) {
            return false;
        }
    }
    return true;
}

Set.prototype.difference = function (setB) {
    for (let elem of setB) {
        this.delete(elem)
    }
}
