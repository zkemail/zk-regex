/* eslint-disable no-prototype-builtins */
/*jslint browser: true*/

const a2z_nosep = "abcdefghijklmnopqrstuvwxyz";
const A2Z_nosep = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const a2f_nosep = "abcdef";
const A2F_nosep = "ABCDEF";
const r0to9_nosep = "0123456789";
const escapeMap = { n: "\n", r: "\r", t: "\t", v: "\v", f: "\f" };
const whitespace = Object.values(escapeMap);
const slash_s = whitespace.join("|");

/** 
 *  Parse regex to a min DFA spec
 *  to support some shorthands that make regex easier to write e.g. [A-Z]
 */
function regexToMinDFASpec(str: string): string {
  // Replace all A-Z with A2Z etc
  let combined_nosep = str
    .replaceAll("A-Z", A2Z_nosep)
    .replaceAll("a-z", a2z_nosep)
    .replaceAll("A-F", A2F_nosep)
    .replaceAll("a-f", a2f_nosep)
    .replaceAll("0-9", r0to9_nosep)
    .replaceAll("\\w", A2Z_nosep + r0to9_nosep + a2z_nosep + "_")
    .replaceAll("\\d", r0to9_nosep)
    .replaceAll("\\s", slash_s);
  // .replaceAll("\\w", A2Z_nosep + r0to9_nosep + a2z_nosep); // I think that there's also an underscore here

  function addPipeInsideBrackets(str: string):string {
    let result: string = "";
    let insideBrackets: boolean = false;
    for (let i = 0; i < str.length; i++) {
      if (str[i] === "[") {
        result += str[i];
        insideBrackets = true;
        continue;
      } else if (str[i] === "]") {
        insideBrackets = false;
      }
      let str_to_add = str[i];
      if (str[i] === "\\") {
        i++;
        str_to_add += str[i];
      }
      result += insideBrackets ? "|" + str_to_add : str_to_add;
    }
    return result.replaceAll("[|", "[").replaceAll("[", "(").replaceAll("]", ")");
  }

  //   function makeCurlyBracesFallback(str) {
  //   let result = "";
  //   let insideBrackets = false;
  //   for (let i = 0; i < str.length; i++) {
  //     if (str[i] === "{") {
  //     result += str[i];
  //     insideBrackets = true;
  //     continue;
  //     } else if (str[i] === "}") {
  //     insideBrackets = false;
  //     }
  //     result += insideBrackets ? "|" + str[i] : str[i];
  //   }
  //   return result.replaceAll("[|", "[").replaceAll("[", "(").replaceAll("]", ")");
  //   }

  function checkIfBracketsHavePipes(str: string): boolean {
    let result: boolean = true;
    let insideBrackets: boolean = false;
    let insideParens: number = 0;
    let indexAt: number = 0;
    for (let i = 0; i < str.length; i++) {
      if (indexAt >= str.length) break;
      if (str[indexAt] === "[") {
        insideBrackets = true;
        indexAt++;
        continue;
      } else if (str[indexAt] === "]") {
        insideBrackets = false;
      }
      if (str[indexAt] === "(") {
        insideParens++;
      } else if (str[indexAt] === ")") {
        insideParens--;
      }
      if (insideBrackets) {
        if (str[indexAt] === "|") {
          indexAt++;
        } else {
          result = false;
          return result;
        }
      }
      if (!insideParens && str[indexAt] === "|") {
        console.log("Error: | outside of parens!");
      }
      if (str[indexAt] === "\\") {
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
      console.log("Did not add brackets correctly!");
    }
  } else {
    combined = combined_nosep;
  }

  return combined;
}

type CusNode = {
    type?: string;
    sub?: CusNode;
    parts?: CusNode[];
    text?: string | [string];
    begin: number;
    end: number;
}

type NfaEdge = [string | [string], NfaNode];

type NfaNode = {
    type: string;
    edges: NfaEdge[];
    id?: string | number;
};

type DfaEdge = [string | [string], DfaNode];

type DfaNode = {
    id: string | number;
    key: string,
    items: NfaNode[],
    symbols: (string | [string])[],
    type: string,
    edges: DfaEdge[],
    trans: Record<string, DfaNode>;
    nature: number;
};


/**
 * Try parsing simple regular expression to syntax tree.
 *
 * Basic grammars:
 *   Empty: S -> ϵ
 *   Cat:   S -> S S
 *   Or:  S -> S | S
 *   Star:  S -> S *
 *   Text:  S -> [0-9a-zA-Z]
 *   S -> ( S )
 *
 * Extension:
 *   Plus:  S -> S + -> S S *
 *   Ques:  S -> S ? -> (S | ϵ)
 *
 * @param {string} text The input regular expression
 * @return {string|object} Returns a string that is an error message if failed to parse the expression,
 *             otherwise returns an object which is the syntax tree.
 */
function parseRegex(text: string): CusNode | string {
  text = regexToMinDFASpec(text);
  "use strict";
  function parseSub(text: (string | [string])[], begin: number, end: number, first: boolean): CusNode | string {
    var i: number,
      sub: CusNode | string,
      last: number = 0,
      node: CusNode = {
          begin: begin,
          end: end,
      },
      virNode: CusNode,
      tempNode: CusNode,
      stack: number = 0,
      parts: CusNode[] = [];
    if (text.length === 0) {
    return "Error: empty input at " + begin + ".";
    }
    if (first) {
    for (i = 0; i <= text.length; i += 1) {
      if (i === text.length || (text[i] === "|" && stack === 0)) {
      if (last === 0 && i === text.length) {
        return parseSub(text, begin + last, begin + i, false);
      }
      sub = parseSub(text.slice(last, i), begin + last, begin + i, true);
      if (typeof sub === "string") {
        return sub;
      }
      parts.push(sub);
      last = i + 1;
      } else if (text[i] === "(") {
      stack += 1;
      } else if (text[i] === ")") {
      stack -= 1;
      }
    }
    if (parts.length === 1) {
      return parts[0];
    }
    node.type = "or";
    node.parts = parts;
    } else {
    for (i = 0; i < text.length; i += 1) {
      if (text[i] === "(") {
      last = i + 1;
      i += 1;
      stack = 1;
      while (i < text.length && stack !== 0) {
        if (text[i] === "(") {
        stack += 1;
        } else if (text[i] === ")") {
        stack -= 1;
        }
        i += 1;
      }
      if (stack !== 0) {
        return "Error: missing right bracket for " + (begin + last) + ".";
      }
      i -= 1;
      sub = parseSub(text.slice(last, i), begin + last, begin + i, true);
      if (typeof sub === "string") {
        return sub;
      }
      sub.begin -= 1;
      sub.end += 1;
      parts.push(sub);
      } else if (text[i] === "*") {
      if (parts.length === 0) {
        return "Error: unexpected * at " + (begin + i) + ".";
      }
      tempNode = { begin: parts[parts.length - 1].begin, end: parts[parts.length - 1].end + 1 };
      tempNode.type = "star";
      tempNode.sub = parts[parts.length - 1];
      parts[parts.length - 1] = tempNode;
      } else if (text[i] === "+") {
      if (parts.length === 0) {
        return "Error: unexpected + at " + (begin + i) + ".";
      }
      virNode = { begin: parts[parts.length - 1].begin, end: parts[parts.length - 1].end + 1 };
      virNode.type = "star";
      virNode.sub = parts[parts.length - 1];
      tempNode = { begin: parts[parts.length - 1].begin, end: parts[parts.length - 1].end + 1 };
      tempNode.type = "cat";
      tempNode.parts = [parts[parts.length - 1], virNode];
      parts[parts.length - 1] = tempNode;
      } else if (text[i] === "?") {
      if (parts.length === 0) {
        return "Error: unexpected + at " + (begin + i) + ".";
      }
      virNode = { begin: parts[parts.length - 1].begin, end: parts[parts.length - 1].end + 1 };
      virNode.type = "empty";
      virNode.sub = parts[parts.length - 1];
      tempNode = { begin: parts[parts.length - 1].begin, end: parts[parts.length - 1].end + 1 };
      tempNode.type = "or";
      tempNode.parts = [parts[parts.length - 1], virNode];
      parts[parts.length - 1] = tempNode;
      } else if (text[i] === "ϵ") {
      tempNode = { begin: begin + i, end: begin + i + 1 };
      tempNode.type = "empty";
      parts.push(tempNode);
      } else if (Array.isArray(text[i])) {
      tempNode = { begin: begin + i, end: begin + i + 1 };
      tempNode.type = "text";
      tempNode.text = text[i][0];
      parts.push(tempNode);
      } else {
      tempNode = { begin: begin + i, end: begin + i + 1 };
      tempNode.type = "text";
      tempNode.text = text[i];
      parts.push(tempNode);
      }
    }
    if (parts.length === 1) {
      return parts[0];
    }
    node.type = "cat";
    node.parts = parts;
    }
    return node;
  }
  
  let new_text: string[] = [];
  let i = 0;
  while (i < text.length) {
    if (text[i] === "\\") {
    const escapeMap = new Map<string, string>([
        ["n", "\n"],
        ["r", "\r"],
        ["t", "\t"],
        ["v", "\v"],
        ["f", "\f"],
        ["^", String.fromCharCode(128)],
    ]);
    const char: string = text[i + 1];
    new_text.push(escapeMap.get(char) ?? char);
    i += 2;
    } else {
    new_text.push(text[i]);
    i += 1;
    }
  }
  return parseSub(new_text, 0, new_text.length, true);
  }


/**
* Convert regular expression to nondeterministic finite automaton.
*
* @param {string} text @see parseRegex()
* @return {object|string}
*/
function regexToNfa(text: string): NfaNode | string {
  'use strict';
  function generateGraph(node: CusNode, start: NfaNode, end: NfaNode, count: number): number {
    var i: number, last: NfaNode, temp: NfaNode, tempStart: NfaNode, tempEnd: NfaNode;
    if (!start.hasOwnProperty('id')) {
      start.id = count;
      count += 1;
    }
    switch (node.type) {
      case 'empty':
        start.edges.push(['ϵ', end]);
        break;
      case 'text':
        start.edges.push([node.text!, end]);
        break;
      case 'cat':
        last = start;
        for (i = 0; i < node.parts!.length - 1; i += 1) {
          temp = { 'type': '', 'edges': [] };
          count = generateGraph(node.parts![i], last, temp, count);
          last = temp;
        }
        count = generateGraph(node.parts![node.parts!.length - 1], last, end, count);
        break;
      case 'or':
        for (i = 0; i < node.parts!.length; i += 1) {
          tempStart = { 'type': '', 'edges': [] };
          tempEnd = { 'type': '', 'edges': [['ϵ', end]] };
          start.edges.push(['ϵ', tempStart]);
          count = generateGraph(node.parts![i], tempStart, tempEnd, count);
        }
        break;
      case 'star':
        tempStart = { 'type': '', 'edges': [] };
        tempEnd = { 'type': '', 'edges': [['ϵ', tempStart], ['ϵ', end]] };
        start.edges.push(['ϵ', tempStart]);
        start.edges.push(['ϵ', end]);
        count = generateGraph(node.sub!, tempStart, tempEnd, count);
        break;
    }
    if (!end.hasOwnProperty('id')) {
      end.id = count;
      count += 1;
    }
    return count;
  }
  var ast = parseRegex(text),
    start = { 'type': 'start', 'edges': [] },
    accept = { 'type': 'accept', 'edges': [] };
  if (typeof ast === 'string') {
    return ast;
  }
  generateGraph(ast, start, accept, 0);
  return start;
}

/**
* Convert nondeterministic finite automaton to deterministic finite automaton.
*
* @param {object} nfa @see regexToNfa(), the function assumes that the given NFA is valid.
* @return {object} dfa Returns the first element of the DFA.
*/
function nfaToDfa(nfa: NfaNode): DfaNode {
  'use strict';
  function getClosure(nodes: NfaNode[]): DfaNode {
    var i: number,
      closure: NfaNode[] = [],
      stack: NfaNode[] = [],
      symbols: (string | [string])[] = [],
      type: string = '',
      top: NfaNode;
    for (i = 0; i < nodes.length; i += 1) {
      stack.push(nodes[i]);
      closure.push(nodes[i]);
      if (nodes[i].type === 'accept') {
        type = 'accept';
      }
    }
    while (stack.length > 0) {
      top = stack.pop()!;
      // If top is of type string and starts with "Error" then return error
      if (typeof top === 'string' && top[0] === 'E' && !top) {
        continue;
      }
      for (i = 0; i < top.edges.length; i += 1) {
        if (top.edges[i][0] === 'ϵ') {
          if (closure.indexOf(top.edges[i][1]) < 0) {
            stack.push(top.edges[i][1]);
            closure.push(top.edges[i][1]);
            if (top.edges[i][1].type === 'accept') {
              type = 'accept';
            }
          }
        } else {
          if (symbols.indexOf(top.edges[i][0]) < 0) {
            symbols.push(top.edges[i][0]);
          }
        }
      }
    }
    closure.sort((a, b) => {
            if (a.id && b.id) {
                return a.id > b.id ? 1 : -1;
            }
            return 0;
        });
    symbols.sort();
    return {
      id: '',
      'key': closure.map(function (x) {
        return x.id;
      }).join(','),
      'items': closure,
      'symbols': symbols,
      'type': type,
      'edges': [],
      'trans': {},
      'nature': 0,
    };
  }
  function getClosedMove(closure: DfaNode, symbol: string | [string]): DfaNode {
    var i,
      j,
      node,
      nexts = [];
    for (i = 0; i < closure.items.length; i += 1) {
      node = closure.items[i];
      for (j = 0; j < node.edges.length; j += 1) {
        if (symbol === node.edges[j][0]) {
          if (nexts.indexOf(node.edges[j][1]) < 0) {
            nexts.push(node.edges[j][1]);
          }
        }
      }
    }
    return getClosure(nexts);
  }
  function toAlphaCount(n: number): string {
    var a = 'A'.charCodeAt(0),
      z = 'Z'.charCodeAt(0),
      len = z - a + 1,
      s = '';
    while (n >= 0) {
      s = String.fromCharCode(n % len + a) + s;
      n = Math.floor(n / len) - 1;
    }
    return s;
  }
  var i: number,
    first: DfaNode = getClosure([nfa]),
    states: Record<string, DfaNode> = {},
    front: number = 0,
    top: DfaNode,
    closure: DfaNode,
    queue: DfaNode[] = [first],
    count: number = 0;
  first.id = toAlphaCount(count);
  states[first.key] = first;
  while (front < queue.length) {
    top = queue[front];
    front += 1;
    for (i = 0; i < top.symbols.length; i += 1) {
      closure = getClosedMove(top, top.symbols[i]);
      if (!states.hasOwnProperty(closure.key)) {
        count += 1;
        closure.id = toAlphaCount(count);
        states[closure.key] = closure;
        queue.push(closure);
      }
      top.trans[top.symbols[i] as string] = states[closure.key];
      top.edges.push([top.symbols[i], states[closure.key]]);
    }
  }
  return first;
}

/**
* Convert the DFA to its minimum form using Hopcroft's algorithm.
*
* @param {object} dfa @see nfaToDfa(), the function assumes that the given DFA is valid.
* @return {object} dfa Returns the first element of the minimum DFA.
*/
function minDfa(dfa: DfaNode) {
  'use strict';
  function getReverseEdges(start: DfaNode): [string[], Record<string, DfaNode>, Record<string, Record<string, (string | number)[]>>] {
    var i: number, top: DfaNode, symbol: string | [string], next: DfaNode,
      front: number = 0,
      queue: DfaNode[] = [start],
      visited: Record<string, boolean> = {},
      symbols: Record<string, boolean> = {},   // The input alphabet
      idMap: Record<string, DfaNode> = {},   // Map id to states
      revEdges: Record<string, Record<string, (string | number)[]>> = {};  // Map id to the ids which connects to the id with an alphabet
    visited[start.id] = true;
    while (front < queue.length) {
      top = queue[front];
      front += 1;
      idMap[top.id] = top;
      for (i = 0; i < top.symbols.length; i += 1) {
        symbol = top.symbols[i];
        if (!symbols.hasOwnProperty(symbol as string)) {
          symbols[symbol as string] = true;
        }
        next = top.trans[symbol as string];
        if (!revEdges.hasOwnProperty(next.id)) {
          revEdges[next.id] = {};
        }
        if (!revEdges[next.id].hasOwnProperty(symbol as string)) {
          revEdges[next.id][symbol as string] = [];
        }
        revEdges[next.id][symbol as string].push(top.id);
        if (!visited.hasOwnProperty(next.id)) {
          visited[next.id] = true;
          queue.push(next);
        }
      }
    }
    return [Object.keys(symbols), idMap, revEdges];
  }
  function hopcroft(symbols: string[], idMap: Record<string, DfaNode>, revEdges: Record<string, Record<string, (string | number)[]>>): string[][] {
    const ids = Object.keys(idMap).sort();
    const partitions: Record<string, string[]> = {};
    const queue: (string | null)[] = [];
    const visited: Record<string, number> = {};

    let front = 0;
    let top: string[] | string | null;
    let i: number;
    let j: number;
    let k: number;
    let keys: string[];
    let key: string;
    let key1: string;
    let key2: string;
    let group1: string[];
    let group2: string[];
    let symbol: string;
    let revGroup: Record<string, boolean>;

    group1 = [];
    group2 = [];
    for (i = 0; i < ids.length; i += 1) {
      if (idMap[ids[i]].type === 'accept') {
        group1.push(ids[i]);
      } else {
        group2.push(ids[i]);
      }
    }
    key = group1.join(',');
    partitions[key] = group1;
    queue.push(key);
    visited[key] = 0;
    if (group2.length !== 0) {
      key = group2.join(',');
      partitions[key] = group2;
      queue.push(key);
    }
    while (front < queue.length) {
      top = queue[front];
      front += 1;
      if (top) {
        top = top.split(',');
        for (i = 0; i < symbols.length; i += 1) {
          symbol = symbols[i];
          revGroup = {};
          for (j = 0; j < top.length; j += 1) {
            if (revEdges.hasOwnProperty(top[j]) && revEdges[top[j]].hasOwnProperty(symbol)) {
              for (k = 0; k < revEdges[top[j]][symbol].length; k += 1) {
                revGroup[revEdges[top[j]][symbol][k]] = true;
              }
            }
          }
          keys = Object.keys(partitions);
          for (j = 0; j < keys.length; j += 1) {
            key = keys[j];
            group1 = [];
            group2 = [];
            for (k = 0; k < partitions[key].length; k += 1) {
              if (revGroup.hasOwnProperty(partitions[key][k])) {
                group1.push(partitions[key][k]);
              } else {
                group2.push(partitions[key][k]);
              }
            }
            if (group1.length !== 0 && group2.length !== 0) {
              delete partitions[key];
              key1 = group1.join(',');
              key2 = group2.join(',');
              partitions[key1] = group1;
              partitions[key2] = group2;
              if (visited.hasOwnProperty(key1)) {
                queue[visited[key1]] = null;
                visited[key1] = queue.length;
                queue.push(key1);
                visited[key2] = queue.length;
                queue.push(key2);
              } else if (group1.length <= group2.length) {
                visited[key1] = queue.length;
                queue.push(key1);
              } else {
                visited[key2] = queue.length;
                queue.push(key2);
              }
            }
          }
        }
      }
    }
    return Object.values(partitions);
  }
  function buildMinNfa(start: DfaNode, partitions: string[][], idMap: Record<string, DfaNode>, revEdges: Record<string, Record<string, (string | number)[]>>): DfaNode {
    var i: number, j: number, temp: string[], node, symbol;
    const nodes: DfaNode[] = [];
    const group: Record<string, number> = {};
    const edges: Record<number, Record<number, Record<string, boolean>>> = {};
    partitions.sort(function (a, b) {
      var ka = a.join(','), kb = b.join(',');
      if (ka < kb) {
        return -1;
      }
      if (ka > kb) {
        return 1;
      }
      return 0;
    });
    for (i = 0; i < partitions.length; i += 1) {
      if (partitions[i].indexOf(start.id.toString()) >= 0) {
        if (i > 0) {
          temp = partitions[i];
          partitions[i] = partitions[0];
          partitions[0] = temp;
        }
        break;
      }
    }
    for (i = 0; i < partitions.length; i += 1) {
      const node: DfaNode = {
        id: (i + 1).toString(),
        key: partitions[i].join(','),
        items: [],
        symbols: [],
        type: idMap[partitions[i][0]].type,
        edges: [],
        trans: {},
        nature: 0,
      };
      for (j = 0; j < partitions[i].length; j += 1) {
        node.items.push(idMap[partitions[i][j]]);
        group[partitions[i][j]] = i;
      }
      edges[i] = {};
      nodes.push(node);
    }
    Object.keys(revEdges).forEach(function (to) {
      Object.keys(revEdges[to]).forEach(function (symbol) {
        revEdges[to][symbol].forEach(function (from) {
          if (!edges[group[from]].hasOwnProperty(group[to])) {
            edges[group[from]][group[to]] = {};
          }
          edges[group[from]][group[to]][symbol] = true;
        });
      });
    });
    Object.keys(edges).forEach((from) => {
        Object.keys(edges[Number(from)]).forEach((to) => {
            const symbol = JSON.stringify(Object.keys(edges[Number(from)][Number(to)]).sort());
            nodes[parseInt(from)].symbols.push(symbol);
            nodes[parseInt(from)].edges.push([symbol, nodes[parseInt(to)]]);
            nodes[parseInt(from)].trans[symbol] = nodes[parseInt(to)];
        });
    });
    return nodes[0];
  }
  var edgesTuple = getReverseEdges(dfa),
    symbols = edgesTuple[0],
    idMap = edgesTuple[1],
    revEdges = edgesTuple[2],
    partitions = hopcroft(symbols, idMap, revEdges);
  return buildMinNfa(dfa, partitions, idMap, revEdges);
}

function toNature(col: string): number {
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

// '(\r\n|\x80)(to|from):([A-Za-z0-9 _."@-]+<)?[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.]+>?\r\n';
// let regex = '(\r\n|\x80)(to|from):((a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9| |_|.|"|@|-)+<)?(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|_|.|-)+@(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|_|.|-)+>?\r\n';

// const key_chars = '(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z)';
// const catch_all = '(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|!|"|#|$|%|&|\'|\\(|\\)|\\*|\\+|,|-|.|/|:|;|<|=|>|\\?|@|[|\\\\|]|^|_|`|{|\\||}|~| |\t|\n|\r|\x0b|\x0c)';
// const catch_all_without_semicolon = '(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|!|"|#|$|%|&|\'|\\(|\\)|\\*|\\+|,|-|.|/|:|<|=|>|\\?|@|[|\\\\|]|^|_|`|{|\\||}|~| |\t|\n|\r|\x0b|\x0c)';
// const base_64 = '(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|\\+|/|=)';
// const word_char = '(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|_)';


function regexToDfa(regex: string): string {
  let nfa = regexToNfa(regex);
  let dfa = minDfa(nfaToDfa(nfa as NfaNode));
  var i: number,
    states: Record<string, DfaNode> = {},
    nodes: DfaNode[] = [],
    stack = [dfa],
    symbols: string[] = [];

  while (stack.length > 0) {
    const top = stack.pop()!;
    if (!states.hasOwnProperty(top.id.toString())) {
      states[top.id] = top;
      top.nature = toNature(top.id.toString());
      nodes.push(top);
      for (i = 0; i < top.edges.length; i += 1) {
        if (top.edges[i][0] !== 'ϵ' && symbols.indexOf(top.edges[i][0] as string) < 0) {
          symbols.push(top.edges[i][0] as string);
        }
        stack.push(top.edges[i][1]);
      }
    }
  }
  nodes.sort(function (a, b) {
    return a.nature - b.nature;
  });
  symbols.sort();
  const graph: Record<string, any>[] = [];
  for (let i = 0; i < nodes.length; i += 1) {
    const curr: Record<string, any> = {};
    curr.type = nodes[i].type;
    curr.edges = {};
    for (let j = 0; j < symbols.length; j += 1) {
      if (nodes[i].trans.hasOwnProperty(symbols[j])) {
        curr.edges[symbols[j]] = nodes[i].trans[symbols[j]].nature - 1;
      }
    }
    graph[nodes[i].nature - 1] = curr;
  }
  // console.log(`graph: ${JSON.stringify(graph, null, 2)}`);

  return JSON.stringify(graph);
}

// function catchAllRegexStr() {
//   return "(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|!|\"|#|$|%|&|'|\\(|\\)|\\*|\\+|,|-|.|/|:|;|<|=|>|\\?|@|\\[|\\\\|\\]|\\^|_|`|{|\\||}|~| |\t|\n|\r|\x0b|\x0c)";
// }

// function catchAllWithoutRNRegexStr() {
//   return "(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|!|\"|#|$|%|&|'|\\(|\\)|\\*|\\+|,|-|.|/|:|;|<|=|>|\\?|@|[|\\\\|]|^|_|`|{|\\||}|~| |\t|\x0b|\x0c)";
// }

// function textContextPrefix() {
//   return `Content-Type: text/plain; charset="UTF-8"\r\n\r\n`;
// }

// function formatRegexPrintable(s) {
//   const escaped_string_json = JSON.stringify(s);
//   const escaped_string = escaped_string_json.slice(1, escaped_string_json.length - 1);
//   return escaped_string
//     .replaceAll("\\\\\\\\", "\\")
//     .replaceAll("\\\\", "\\")
//     .replaceAll("/", "\\/")
//     .replaceAll("\u000b", "\\♥")
//     .replaceAll("^", "\\^")
//     .replaceAll("$", "\\$")
//     .replaceAll("|[|", "|\\[|")
//     .replaceAll("|]|", "|\\]|")
//     .replaceAll("|.|", "|\\.|")
//     .replaceAll("|$|", "|\\$|")
//     .replaceAll("|^|", "|\\^|");
// }

// module.exports = {
//   regexToDfa
// };
