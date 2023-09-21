/*jslint browser: true*/
const { minDfa, nfaToDfa, regexToNfa } = require('./lexical');

/** This section defines helper regex components -- to edit the regex used, edit the return
 * of the test_regex function.
 * All of the relevant regexes are in the main repo README.
 */

// Helper components

const a2z_nosep = 'abcdefghijklmnopqrstuvwxyz';
const A2Z_nosep = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const a2f_nosep = 'abcdef';
const A2F_nosep = 'ABCDEF';
const r0to9_nosep = '0123456789';

// TODO: Note that this is replicated code in lexical.js as well
// Note that ^ has to be manually replaced with \x80 in the regex
const escapeMap = { n: '\n', r: '\r', t: '\t', v: '\v', f: '\f' };
let whitespace = Object.values(escapeMap);
const slash_s = whitespace.join('|');

// Note that this is not complete and very case specific i.e. can only handle a-z and a-f, and not a-c.
// This function expands [] sections to convert values for https://zkregex.com/min_dfa
// The input is a regex with [] and special characters (i.e. the first line of min_dfa tool)
// The output is expanded regexes without any special characters
function regexToMinDFASpec(str) {
    // Replace all A-Z with A2Z etc
    // TODO: Upstream this to min_dfa
    let combined_nosep = str
        .replaceAll('A-Z', A2Z_nosep)
        .replaceAll('a-z', a2z_nosep)
        .replaceAll('A-F', A2F_nosep)
        .replaceAll('a-f', a2f_nosep)
        .replaceAll('0-9', r0to9_nosep)
        .replaceAll('\\w', A2Z_nosep + r0to9_nosep + a2z_nosep + '_')
        .replaceAll('\\d', r0to9_nosep)
        .replaceAll('\\s', slash_s);

    function addPipeInsideBrackets(str) {
        let result = '';
        let insideBrackets = false;
        for (let i = 0; i < str.length; i++) {
            if (str[i] === '[') {
                result += str[i];
                insideBrackets = true;
                continue;
            } else if (str[i] === ']') {
                insideBrackets = false;
            }
            let str_to_add = str[i];
            if (str[i] === '\\') {
                i++;
                str_to_add += str[i];
            }
            result += insideBrackets ? '|' + str_to_add : str_to_add;
        }
        return result.replaceAll('[|', '[').replaceAll('[', '(').replaceAll(']', ')');
    }

    //   function makeCurlyBracesFallback(str) {
    //     let result = "";
    //     let insideBrackets = false;
    //     for (let i = 0; i < str.length; i++) {
    //       if (str[i] === "{") {
    //         result += str[i];
    //         insideBrackets = true;
    //         continue;
    //       } else if (str[i] === "}") {
    //         insideBrackets = false;
    //       }
    //       result += insideBrackets ? "|" + str[i] : str[i];
    //     }
    //     return result.replaceAll("[|", "[").replaceAll("[", "(").replaceAll("]", ")");
    //   }

    function checkIfBracketsHavePipes(str) {
        let result = true;
        let insideBrackets = false;
        let insideParens = 0;
        let indexAt = 0;
        for (let i = 0; i < str.length; i++) {
            if (indexAt >= str.length) break;
            if (str[indexAt] === '[') {
                insideBrackets = true;
                indexAt++;
                continue;
            } else if (str[indexAt] === ']') {
                insideBrackets = false;
            }
            if (str[indexAt] === '(') {
                insideParens++;
            } else if (str[indexAt] === ')') {
                insideParens--;
            }
            if (insideBrackets) {
                if (str[indexAt] === '|') {
                    indexAt++;
                } else {
                    result = false;
                    return result;
                }
            }
            if (!insideParens && str[indexAt] === '|') {
                console.log('Error: | outside of parens!');
            }
            if (str[indexAt] === '\\') {
                indexAt++;
            }
            indexAt++;
        }
        return result;
    }

    let combined;
    if (!checkIfBracketsHavePipes(combined_nosep)) {
    // console.log("Adding pipes within brackets between everything!");
        combined = addPipeInsideBrackets(combined_nosep);
        if (!checkIfBracketsHavePipes(combined)) {
            console.log('Did not add brackets correctly!');
        }
    } else {
        combined = combined_nosep;
    }
    return combined;
}

function toNature(col) {
    var i,
        j,
        base = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
        result = 0;
    if ('1' <= col[0] && col[0] <= '9') {
        result = parseInt(col, 10);
    } else {
        for (i = 0, j = col.length - 1; i < col.length; i += 1, j -= 1) {
            result += Math.pow(base.length, j) * (base.indexOf(col[i]) + 1);
        }
    }
    return result;
}

function regexToGraph(regex) {
    let nfa = regexToNfa(regex);
    let dfa = minDfa(nfaToDfa(nfa));

    var i,
        states = {},
        nodes = [],
        stack = [dfa],
        symbols = [],
        top;

    while (stack.length > 0) {
        top = stack.pop();
        if (!Object.keys(states).includes(top.id)) {
            states[top.id] = top;
            top.nature = toNature(top.id);
            nodes.push(top);
            for (i = 0; i < top.edges.length; i += 1) {
                if (top.edges[i][0] !== 'ϵ' && symbols.indexOf(top.edges[i][0]) < 0) {
                    symbols.push(top.edges[i][0]);
                }
                stack.push(top.edges[i][1]);
            }
        }
    }
    nodes.sort(function (a, b) {
        return a.nature - b.nature;
    });
    symbols.sort();

    let graph = [];
    for (let i = 0; i < nodes.length; i += 1) {
        let curr = {};
        curr.type = nodes[i].type;
        curr.edges = {};
        for (let j = 0; j < symbols.length; j += 1) {
            if (Object.keys(nodes[i].trans).includes(symbols[j])) {
                curr.edges[symbols[j]] = nodes[i].trans[symbols[j]].nature - 1;
            }
        }
        graph[nodes[i].nature - 1] = curr;
    }

    return JSON.stringify(graph);
}

if (typeof require === 'function') {
    exports.regexToMinDFASpec = regexToMinDFASpec;
    exports.toNature = toNature;
    exports.regexToGraph = regexToGraph;
}
