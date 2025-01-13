use crate::{
    errors::CompilerError,
    regex::get_accepted_state,
    structs::{DFAGraph, RegexAndDFA},
};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs::File,
    io::Write,
    path::Path,
};

/// Builds a reverse graph from a DFA graph and collects accept nodes.
///
/// This function creates a reverse graph where the direction of edges is inverted,
/// and collects all accepting states.
///
/// # Arguments
///
/// * `state_len` - The number of states in the DFA.
/// * `dfa_graph` - A reference to the original DFA graph.
///
/// # Returns
///
/// A tuple containing:
/// * The reverse graph as a `BTreeMap<usize, BTreeMap<usize, Vec<u8>>>`.
/// * A `BTreeSet<usize>` of accepting state IDs.
///
/// # Errors
///
/// Returns a `CompilerError::NoAcceptedState` if no accepting states are found.
fn build_reverse_graph(
    state_len: usize,
    dfa_graph: &DFAGraph,
) -> (BTreeMap<usize, BTreeMap<usize, Vec<u8>>>, BTreeSet<usize>) {
    let mut rev_graph = BTreeMap::<usize, BTreeMap<usize, Vec<u8>>>::new();
    let mut accept_nodes = BTreeSet::<usize>::new();

    for i in 0..state_len {
        rev_graph.insert(i, BTreeMap::new());
    }

    for (i, node) in dfa_graph.states.iter().enumerate() {
        for (k, v) in &node.transitions {
            let chars: Vec<u8> = v.iter().cloned().collect();
            rev_graph.get_mut(k).unwrap().insert(i, chars);
        }

        if node.state_type == "accept" {
            accept_nodes.insert(i);
        }
    }

    if accept_nodes.is_empty() {
        panic!("Accept node must exist");
    }

    (rev_graph, accept_nodes)
}

/// Optimizes character ranges by grouping consecutive characters and identifying individual characters.
///
/// This function takes a slice of u8 values (representing ASCII characters) and groups them into
/// ranges where possible, while also identifying individual characters that don't fit into ranges.
///
/// # Arguments
///
/// * `k` - A slice of u8 values representing ASCII characters.
///
/// # Returns
///
/// A tuple containing:
/// * A Vec of (u8, u8) tuples representing optimized character ranges (min, max).
/// * A BTreeSet of u8 values representing individual characters not included in ranges.
///
/// # Note
///
/// Ranges are only created for sequences of 16 or more consecutive characters.
fn optimize_char_ranges(k: &[u8]) -> (Vec<(u8, u8)>, BTreeSet<u8>) {
    let mut min_maxes = vec![];
    let mut vals = k.iter().cloned().collect::<BTreeSet<u8>>();

    if k.is_empty() {
        return (min_maxes, vals);
    }

    let mut cur_min = k[0];
    let mut cur_max = k[0];

    for &val in &k[1..] {
        if cur_max == val {
            continue;
        } else if cur_max + 1 == val {
            cur_max = val;
        } else {
            if cur_max - cur_min >= 16 {
                min_maxes.push((cur_min, cur_max));
            }
            cur_min = val;
            cur_max = val;
        }
    }

    if cur_max - cur_min >= 16 {
        min_maxes.push((cur_min, cur_max));
    }

    for (min, max) in &min_maxes {
        for code in *min..=*max {
            vals.remove(&code);
        }
    }

    (min_maxes, vals)
}

/// Adds a range check for character comparisons in the Circom circuit.
///
/// This function either reuses an existing range check or creates a new one,
/// adding the necessary Circom code lines and updating the relevant counters.
///
/// # Arguments
///
/// * `lines` - A mutable reference to a Vec of Strings containing Circom code lines.
/// * `range_checks` - A mutable reference to a 2D Vec storing existing range checks.
/// * `eq_outputs` - A mutable reference to a Vec storing equality check outputs.
/// * `min` - The minimum value of the range.
/// * `max` - The maximum value of the range.
/// * `lt_i` - A mutable reference to the current LessThan component index.
/// * `and_i` - A mutable reference to the current AND component index.
fn add_range_check(
    lines: &mut Vec<String>,
    range_checks: &mut Vec<Vec<Option<(usize, usize)>>>,
    eq_outputs: &mut Vec<(&str, usize)>,
    min: u8,
    max: u8,
    lt_i: &mut usize,
    and_i: &mut usize,
) {
    if let Some((_, and_i)) = range_checks[min as usize][max as usize] {
        eq_outputs.push(("and", and_i));
    } else {
        lines.push(format!("\t\tlt[{}][i] = LessEqThan(8);", *lt_i));
        lines.push(format!("\t\tlt[{}][i].in[0] <== {};", *lt_i, min));
        lines.push(format!("\t\tlt[{}][i].in[1] <== in[i];", *lt_i));
        lines.push(format!("\t\tlt[{}][i] = LessEqThan(8);", *lt_i + 1));
        lines.push(format!("\t\tlt[{}][i].in[0] <== in[i];", *lt_i + 1));
        lines.push(format!("\t\tlt[{}][i].in[1] <== {};", *lt_i + 1, max));
        lines.push(format!("\t\tand[{}][i] = AND();", *and_i));
        lines.push(format!(
            "\t\tand[{}][i].a <== lt[{}][i].out;",
            *and_i, *lt_i
        ));
        lines.push(format!(
            "\t\tand[{}][i].b <== lt[{}][i].out;",
            *and_i,
            *lt_i + 1
        ));

        eq_outputs.push(("and", *and_i));
        range_checks[min as usize][max as usize] = Some((*lt_i, *and_i));
        *lt_i += 2;
        *and_i += 1;
    }
}

/// Adds an equality check for a specific character code in the Circom circuit.
///
/// This function either reuses an existing equality check or creates a new one,
/// adding the necessary Circom code lines and updating the relevant counter.
///
/// # Arguments
///
/// * `lines` - A mutable reference to a Vec of Strings containing Circom code lines.
/// * `eq_checks` - A mutable reference to a Vec storing existing equality checks.
/// * `code` - The ASCII code of the character to check for equality.
/// * `eq_i` - A mutable reference to the current equality component index.
///
/// # Returns
///
/// The index of the equality check component used or created.
fn add_eq_check(
    lines: &mut Vec<String>,
    eq_checks: &mut Vec<Option<usize>>,
    code: u8,
    eq_i: &mut usize,
) -> usize {
    if let Some(index) = eq_checks[code as usize] {
        index
    } else {
        lines.push(format!("\t\teq[{}][i] = IsEqual();", *eq_i));
        lines.push(format!("\t\teq[{}][i].in[0] <== in[i];", *eq_i));
        lines.push(format!("\t\teq[{}][i].in[1] <== {};", *eq_i, code));
        eq_checks[code as usize] = Some(*eq_i);
        let result = *eq_i;
        *eq_i += 1;
        result
    }
}

/// Adds a state transition to the Circom circuit.
///
/// This function creates an AND gate for the state transition and handles the
/// equality outputs, potentially creating a MultiOR gate if necessary.
///
/// # Arguments
///
/// * `lines` - A mutable reference to a Vec of Strings containing Circom code lines.
/// * `zero_starting_and_idxes` - A mutable reference to a BTreeMap storing AND indices for zero-starting states.
/// * `i` - The current state index.
/// * `prev_i` - The previous state index.
/// * `eq_outputs` - A Vec of tuples containing equality output types and indices.
/// * `and_i` - A mutable reference to the current AND gate index.
/// * `multi_or_checks1` - A mutable reference to a BTreeMap storing MultiOR checks.
/// * `multi_or_i` - A mutable reference to the current MultiOR gate index.
fn add_state_transition(
    lines: &mut Vec<String>,
    zero_starting_and_idxes: &mut BTreeMap<usize, Vec<usize>>,
    i: usize,
    prev_i: usize,
    eq_outputs: Vec<(&str, usize)>,
    and_i: &mut usize,
    multi_or_checks1: &mut BTreeMap<String, usize>,
    multi_or_i: &mut usize,
) {
    lines.push(format!("\t\tand[{}][i] = AND();", and_i));
    lines.push(format!(
        "\t\tand[{}][i].a <== states[i][{}];",
        and_i, prev_i
    ));

    if eq_outputs.len() == 1 {
        lines.push(format!(
            "\t\tand[{}][i].b <== {}[{}][i].out;",
            and_i, eq_outputs[0].0, eq_outputs[0].1
        ));
        if prev_i == 0 {
            zero_starting_and_idxes.get_mut(&i).unwrap().push(*and_i);
        }
    } else if eq_outputs.len() > 1 {
        let eq_outputs_key = serde_json::to_string(&eq_outputs).unwrap();
        if let Some(&multi_or_index) = multi_or_checks1.get(&eq_outputs_key) {
            lines.push(format!(
                "\t\tand[{}][i].b <== multi_or[{}][i].out;",
                and_i, multi_or_index
            ));
        } else {
            lines.push(format!(
                "\t\tmulti_or[{}][i] = MultiOR({});",
                *multi_or_i,
                eq_outputs.len()
            ));
            for (output_i, (eq_type, eq_i)) in eq_outputs.iter().enumerate() {
                lines.push(format!(
                    "\t\tmulti_or[{}][i].in[{}] <== {}[{}][i].out;",
                    *multi_or_i, output_i, eq_type, eq_i
                ));
            }
            lines.push(format!(
                "\t\tand[{}][i].b <== multi_or[{}][i].out;",
                *and_i, *multi_or_i
            ));
            multi_or_checks1.insert(eq_outputs_key, *multi_or_i);
            *multi_or_i += 1;
        }
        if prev_i == 0 {
            zero_starting_and_idxes.get_mut(&i).unwrap().push(*and_i);
        }
    }

    *and_i += 1;
}

/// Helper function to add a MultiOR gate to the Circom circuit.
fn add_multi_or_gate(
    lines: &mut Vec<String>,
    outputs: &[usize],
    multi_or_i: &mut usize,
    i: usize,
    state_var: &str,
) {
    lines.push(format!(
        "\t\tmulti_or[{multi_or_i}][i] = MultiOR({});",
        outputs.len()
    ));
    for (output_i, and_i) in outputs.iter().enumerate() {
        lines.push(format!(
            "\t\tmulti_or[{multi_or_i}][i].in[{output_i}] <== and[{and_i}][i].out;"
        ));
    }
    lines.push(format!(
        "\t\t{state_var}[i+1][{i}] <== multi_or[{multi_or_i}][i].out;"
    ));
}

/// Adds a state update to the Circom circuit.
///
/// This function handles the update of state variables, potentially creating
/// a MultiOR gate if there are multiple outputs to combine.
///
/// # Arguments
///
/// * `lines` - A mutable reference to a Vec of Strings containing Circom code lines.
/// * `i` - The current state index.
/// * `outputs` - A Vec of output indices to be combined.
/// * `zero_starting_states` - A mutable reference to a Vec of zero-starting state indices.
/// * `multi_or_checks2` - A mutable reference to a BTreeMap storing MultiOR checks.
/// * `multi_or_i` - A mutable reference to the current MultiOR gate index.
fn add_state_update(
    lines: &mut Vec<String>,
    i: usize,
    outputs: Vec<usize>,
    zero_starting_states: &[usize],
    multi_or_checks2: &mut BTreeMap<String, usize>,
    multi_or_i: &mut usize,
) {
    let is_zero_starting = zero_starting_states.contains(&i);
    let state_var = if is_zero_starting {
        "states_tmp"
    } else {
        "states"
    };

    match outputs.len() {
        0 => lines.push(format!("\t\t{state_var}[i+1][{i}] <== 0;")),
        1 => lines.push(format!(
            "\t\t{state_var}[i+1][{i}] <== and[{}][i].out;",
            outputs[0]
        )),
        _ => {
            let outputs_key = serde_json::to_string(&outputs).expect("Failed to serialize outputs");
            if let Some(&multi_or_index) = multi_or_checks2.get(&outputs_key) {
                lines.push(format!(
                    "\t\t{state_var}[i+1][{i}] <== multi_or[{multi_or_index}][i].out;"
                ));
            } else {
                add_multi_or_gate(lines, &outputs, multi_or_i, i, state_var);
                multi_or_checks2.insert(outputs_key, *multi_or_i);
                *multi_or_i += 1;
            }
        }
    }
}

/// Adds the 'from_zero_enabled' logic to the Circom circuit.
///
/// This function creates a MultiNOR gate that checks if all non-zero states are inactive,
/// which indicates that the current state is the initial (zero) state.
///
/// # Arguments
///
/// * `lines` - A mutable reference to a Vec of Strings containing Circom code lines.
/// * `state_len` - The total number of states in the DFA.
/// * `zero_starting_states` - A reference to a Vec of indices of zero-starting states.
fn add_from_zero_enabled(
    lines: &mut Vec<String>,
    state_len: usize,
    zero_starting_states: &Vec<usize>,
) {
    lines.push(format!(
        "\t\tfrom_zero_enabled[i] <== MultiNOR({})([{}]);",
        state_len - 1,
        (1..state_len)
            .map(|i| (if zero_starting_states.contains(&i) {
                format!("states_tmp[i+1][{}]", i)
            } else {
                format!("states[i+1][{}]", i)
            }))
            .collect::<Vec<_>>()
            .join(", ")
    ));
}

/// Adds updates for zero-starting states to the Circom circuit.
///
/// This function creates MultiOR gates for each zero-starting state,
/// combining the temporary state with the AND outputs of transitions
/// from the zero state, gated by the 'from_zero_enabled' signal.
///
/// # Arguments
///
/// * `lines` - A mutable reference to a Vec of Strings containing Circom code lines.
/// * `zero_starting_and_idxes` - A reference to a BTreeMap mapping state indices to their corresponding AND gate indices.
fn add_zero_starting_state_updates(
    lines: &mut Vec<String>,
    zero_starting_and_idxes: &BTreeMap<usize, Vec<usize>>,
) {
    for (i, vec) in zero_starting_and_idxes {
        if vec.is_empty() {
            continue;
        }
        lines.push(format!(
            "\t\tstates[i+1][{}] <== MultiOR({})([states_tmp[i+1][{}], {}]);",
            i,
            vec.len() + 1,
            i,
            vec.iter()
                .map(|and_i| format!("from_zero_enabled[i] * and[{}][i].out", and_i))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
}

/// Adds state change detection logic to the Circom circuit.
///
/// This function creates inputs for the state_changed component,
/// which detects changes in non-zero states between consecutive steps.
///
/// # Arguments
///
/// * `lines` - A mutable reference to a Vec of Strings containing Circom code lines.
/// * `state_len` - The total number of states in the DFA.
fn add_state_changed_updates(lines: &mut Vec<String>, state_len: usize) {
    for i in 1..state_len {
        lines.push(format!(
            "\t\tstate_changed[i].in[{}] <== states[i+1][{}];",
            i - 1,
            i
        ));
    }
}

/// Generates the state transition logic for the Circom circuit.
///
/// This function creates the core logic for state transitions in the DFA,
/// including range checks, equality checks, and multi-OR operations.
///
/// # Arguments
///
/// * `rev_graph` - A reference to the reverse graph of the DFA.
/// * `state_len` - The total number of states in the DFA.
/// * `end_anchor` - A boolean indicating whether an end anchor is present.
///
/// # Returns
///
/// A tuple containing:
/// * The number of equality checks used.
/// * The number of less-than checks used.
/// * The number of AND gates used.
/// * The number of multi-OR gates used.
/// * A Vec of Strings containing the generated Circom code lines.
fn generate_state_transition_logic(
    rev_graph: &BTreeMap<usize, BTreeMap<usize, Vec<u8>>>,
    state_len: usize,
    end_anchor: bool,
) -> (usize, usize, usize, usize, Vec<String>) {
    let mut eq_i = 0;
    let mut lt_i = 0;
    let mut and_i = 0;
    let mut multi_or_i = 0;

    let mut range_checks = vec![vec![None; 256]; 256];
    let mut eq_checks = vec![None; 256];
    let mut multi_or_checks1 = BTreeMap::<String, usize>::new();
    let mut multi_or_checks2 = BTreeMap::<String, usize>::new();
    let mut zero_starting_states = vec![];
    let mut zero_starting_and_idxes = BTreeMap::<usize, Vec<usize>>::new();

    let mut lines = vec![];

    lines.push("\tfor (var i = 0; i < num_bytes; i++) {".to_string());
    lines.push(format!(
        "\t\tstate_changed[i] = MultiOR({});",
        state_len - 1
    ));
    lines.push("\t\tstates[i][0] <== 1;".to_string());

    if end_anchor {
        lines.push(
            "\t\tpadding_start[i+1] <== IsNotZeroAcc()(padding_start[i], in[i]);".to_string(),
        );
    }

    for i in 1..state_len {
        let mut outputs = vec![];
        zero_starting_and_idxes.insert(i, vec![]);

        for (prev_i, chars) in rev_graph.get(&i).unwrap_or(&BTreeMap::new()) {
            if *prev_i == 0 {
                zero_starting_states.push(i);
            }
            let mut k = chars.clone();
            k.retain(|&x| x != 0);
            k.sort();

            let mut eq_outputs = vec![];

            let (min_maxes, individual_chars) = optimize_char_ranges(&k);

            for (min, max) in min_maxes {
                add_range_check(
                    &mut lines,
                    &mut range_checks,
                    &mut eq_outputs,
                    min,
                    max,
                    &mut lt_i,
                    &mut and_i,
                );
            }

            for &code in &individual_chars {
                let eq_index = add_eq_check(&mut lines, &mut eq_checks, code, &mut eq_i);
                eq_outputs.push(("eq", eq_index));
            }

            add_state_transition(
                &mut lines,
                &mut zero_starting_and_idxes,
                i,
                *prev_i,
                eq_outputs,
                &mut and_i,
                &mut multi_or_checks1,
                &mut multi_or_i,
            );

            if *prev_i != 0 {
                outputs.push(and_i - 1);
            }
        }

        add_state_update(
            &mut lines,
            i,
            outputs,
            &mut zero_starting_states,
            &mut multi_or_checks2,
            &mut multi_or_i,
        );
    }

    add_from_zero_enabled(&mut lines, state_len, &zero_starting_states);
    add_zero_starting_state_updates(&mut lines, &zero_starting_and_idxes);
    add_state_changed_updates(&mut lines, state_len);

    lines.push("\t}".to_string());

    (eq_i, lt_i, and_i, multi_or_i, lines)
}

/// Generates the declarations for the Circom circuit.
///
/// This function creates the initial declarations and setup for the Circom template,
/// including pragma, includes, input/output signals, and component declarations.
///
/// # Arguments
///
/// * `template_name` - The name of the Circom template.
/// * `regex_str` - The regular expression string.
/// * `state_len` - The total number of states in the DFA.
/// * `eq_i` - The number of equality components.
/// * `lt_i` - The number of less-than components.
/// * `and_i` - The number of AND components.
/// * `multi_or_i` - The number of multi-OR components.
/// * `end_anchor` - A boolean indicating whether an end anchor is present.
///
/// # Returns
///
/// A Vec of Strings containing the generated Circom declarations.
fn generate_declarations(
    template_name: &str,
    regex_str: &str,
    state_len: usize,
    eq_i: usize,
    lt_i: usize,
    and_i: usize,
    multi_or_i: usize,
    end_anchor: bool,
) -> Vec<String> {
    let mut declarations = vec![
        "pragma circom 2.1.5;\n".to_string(),
        "include \"@zk-email/zk-regex-circom/circuits/regex_helpers.circom\";\n".to_string(),
        format!(
            "// regex: {}",
            regex_str.replace('\n', "\\n").replace('\r', "\\r")
        ),
        format!("template {}(msg_bytes, is_safe) {{", template_name),
        "\tsignal input msg[msg_bytes];".to_string(),
        "\tsignal output out;".to_string(),
        "".to_string(),
        "\tvar num_bytes = msg_bytes+1;".to_string(),
        "\tsignal in[num_bytes];".to_string(),
        "\tsignal in_range_checks[msg_bytes];".to_string(),
        "\tin[0]<==255;".to_string(),
        "\tfor (var i = 0; i < msg_bytes; i++) {".to_string(),
        "\t\tif (is_safe) {".to_string(),
        "\t\t\tin_range_checks[i] <== SemiSafeLessThan(8)([msg[i], 255]);".to_string(),
        "\t\t} else {".to_string(),
        "\t\t\tin_range_checks[i] <== LessThan(8)([msg[i], 255]);".to_string(),
        "\t\t}".to_string(),
        "\t\tin_range_checks[i] === 1;".to_string(),
        "\t\tin[i+1] <== msg[i];".to_string(),
        "\t}".to_string(),
        "".to_string(),
    ];

    if eq_i > 0 {
        declarations.push(format!("\tcomponent eq[{}][num_bytes];", eq_i));
    }

    if lt_i > 0 {
        declarations.push(format!("\tcomponent lt[{}][num_bytes];", lt_i));
    }

    if and_i > 0 {
        declarations.push(format!("\tcomponent and[{}][num_bytes];", and_i));
    }

    if multi_or_i > 0 {
        declarations.push(format!("\tcomponent multi_or[{}][num_bytes];", multi_or_i));
    }

    declarations.extend([
        format!("\tsignal states[num_bytes+1][{state_len}];"),
        format!("\tsignal states_tmp[num_bytes+1][{state_len}];"),
        "\tsignal from_zero_enabled[num_bytes+1];".to_string(),
        "\tfrom_zero_enabled[num_bytes] <== 0;".to_string(),
        "\tcomponent state_changed[num_bytes];".to_string(),
        "".to_string(),
    ]);

    if end_anchor {
        declarations.extend([
            "\tsignal padding_start[num_bytes+1];".to_string(),
            "\tpadding_start[0] <== 0;".to_string(),
        ]);
    }

    declarations
}

/// Generates the initialization code for the Circom circuit.
///
/// This function creates the code to initialize all states except the first one to 0.
///
/// # Arguments
///
/// * `state_len` - The total number of states in the DFA.
///
/// # Returns
///
/// A Vec of Strings containing the generated initialization code.
fn generate_init_code(state_len: usize) -> Vec<String> {
    vec![
        format!("\tfor (var i = 1; i < {state_len}; i++) {{"),
        "\t\tstates[0][i] <== 0;".to_string(),
        "\t}".to_string(),
        "".to_string(),
    ]
}

/// Generates the acceptance logic for the Circom circuit.
///
/// This function creates the code to check if the DFA has reached an accepting state,
/// and handles the end anchor logic if present.
///
/// # Arguments
///
/// * `accept_nodes` - A BTreeSet of accepting state indices.
/// * `end_anchor` - A boolean indicating whether an end anchor is present.
///
/// # Returns
///
/// A Vec of Strings containing the generated acceptance logic code.
///
/// # Panics
///
/// Panics if there are no accept nodes or if there is more than one accept node.
fn generate_accept_logic(accept_nodes: BTreeSet<usize>, end_anchor: bool) -> Vec<String> {
    let mut accept_lines = vec![];

    if accept_nodes.is_empty() {
        panic!("Accept node must exist");
    }

    if accept_nodes.len() != 1 {
        panic!("The size of accept nodes must be one");
    }

    let accept_node = *accept_nodes.iter().next().unwrap();

    accept_lines.push("".to_string());
    accept_lines.push("\tcomponent is_accepted = MultiOR(num_bytes+1);".to_string());
    accept_lines.push("\tfor (var i = 0; i <= num_bytes; i++) {".to_string());
    accept_lines.push(format!(
        "\t\tis_accepted.in[i] <== states[i][{}];",
        accept_node
    ));
    accept_lines.push("\t}".to_string());

    if end_anchor {
        accept_lines.push("\tsignal end_anchor_check[num_bytes+1][2];".to_string());
        accept_lines.push("\tend_anchor_check[0][1] <== 0;".to_string());
        accept_lines.push("\tfor (var i = 0; i < num_bytes; i++) {".to_string());
        accept_lines.push(
            "\t\tend_anchor_check[i+1][0] <== IsEqual()([i, padding_start[num_bytes]]);"
                .to_string(),
        );
        accept_lines.push(
            format!("\t\tend_anchor_check[i+1][1] <== end_anchor_check[i][1] + states[i][{}] * end_anchor_check[i+1][0];", accept_node)
        );
        accept_lines.push("\t}".to_string());
        accept_lines
            .push("\tout <== is_accepted.out * end_anchor_check[num_bytes][1];".to_string());
    } else {
        accept_lines.push("\tout <== is_accepted.out;".to_string());
    }

    accept_lines
}

/// Generates the complete Circom circuit as a string.
///
/// This function orchestrates the generation of all parts of the Circom circuit,
/// including declarations, initialization code, state transition logic, and acceptance logic.
///
/// # Arguments
///
/// * `dfa_graph` - A reference to the DFA graph.
/// * `template_name` - The name of the Circom template.
/// * `regex_str` - The regular expression string.
/// * `end_anchor` - A boolean indicating whether an end anchor is present.
///
/// # Returns
///
/// A String containing the complete Circom circuit code.
fn gen_circom_allstr(
    dfa_graph: &DFAGraph,
    template_name: &str,
    regex_str: &str,
    end_anchor: bool,
) -> String {
    let state_len = dfa_graph.states.len();

    let (rev_graph, accept_nodes) = build_reverse_graph(state_len, dfa_graph);

    let (eq_i, lt_i, and_i, multi_or_i, lines) =
        generate_state_transition_logic(&rev_graph, state_len, end_anchor);

    let declarations = generate_declarations(
        template_name,
        regex_str,
        state_len,
        eq_i,
        lt_i,
        and_i,
        multi_or_i,
        end_anchor,
    );

    let init_code = generate_init_code(state_len);

    let accept_lines = generate_accept_logic(accept_nodes, end_anchor);

    let final_code = [declarations, init_code, lines, accept_lines].concat();

    final_code.join("\n")
}

/// Writes the consecutive logic for the Circom circuit.
///
/// This function generates the logic to check for consecutive accepted states.
///
/// # Arguments
///
/// * `accepted_state` - The index of the accepted state.
///
/// # Returns
///
/// A String containing the generated Circom code for consecutive logic.
fn write_consecutive_logic(accepted_state: usize) -> String {
    let mut logic = String::new();
    logic += "\n";
    logic += "\tsignal is_consecutive[msg_bytes+1][3];\n";
    logic += "\tis_consecutive[msg_bytes][2] <== 0;\n";
    logic += "\tfor (var i = 0; i < msg_bytes; i++) {\n";
    logic += &format!(
        "\t\tis_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][{accepted_state}] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];\n"
    );
    logic +=
        "\t\tis_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];\n";
    logic += &format!(
        "\t\tis_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][{accepted_state}], is_consecutive[msg_bytes-1-i][1]]);\n"
    );
    logic += "\t}\n";
    logic
}

/// Writes the previous states logic for the Circom circuit.
///
/// This function generates the logic to compute previous states based on transitions.
///
/// # Arguments
///
/// * `idx` - The index of the current substring.
/// * `ranges` - A slice of references to tuples representing state transitions.
///
/// # Returns
///
/// A String containing the generated Circom code for previous states.
fn write_prev_states(idx: usize, ranges: &[&(usize, usize)]) -> String {
    let mut prev_states = String::new();
    for (trans_idx, &(cur, _)) in ranges.iter().enumerate() {
        if *cur == 0 {
            prev_states += &format!(
                "\t\tprev_states{idx}[{trans_idx}][i] <== from_zero_enabled[i+1] * states[i+1][{cur}];\n"
            );
        } else {
            prev_states += &format!(
                "\t\tprev_states{idx}[{trans_idx}][i] <== (1 - from_zero_enabled[i+1]) * states[i+1][{cur}];\n"
            );
        }
    }
    prev_states
}

/// Writes the substring logic for the Circom circuit.
///
/// This function generates the logic to compute if a substring is present.
///
/// # Arguments
///
/// * `idx` - The index of the current substring.
/// * `ranges` - A slice of references to tuples representing state transitions.
///
/// # Returns
///
/// A String containing the generated Circom code for substring logic.
fn write_is_substr(idx: usize, ranges: &[&(usize, usize)]) -> String {
    let multi_or_inputs = ranges
        .iter()
        .enumerate()
        .map(|(trans_idx, (_, next))| {
            format!("prev_states{idx}[{trans_idx}][i] * states[i+2][{next}]")
        })
        .collect::<Vec<_>>()
        .join(", ");

    format!(
        "\t\tis_substr{idx}[i] <== MultiOR({})([{multi_or_inputs}]);\n",
        ranges.len()
    )
}

/// Writes the reveal logic for the Circom circuit.
///
/// This function generates the logic to reveal a substring if it's present and consecutive.
///
/// # Arguments
///
/// * `idx` - The index of the current substring.
///
/// # Returns
///
/// A String containing the generated Circom code for reveal logic.
fn write_is_reveal_and_reveal(idx: usize) -> String {
    let mut reveal = String::new();
    reveal += &format!(
        "\t\tis_reveal{idx}[i] <== MultiAND(3)([out, is_substr{idx}[i], is_consecutive[i][2]]);\n"
    );
    reveal += &format!("\t\treveal{idx}[i] <== in[i+1] * is_reveal{idx}[i];\n");
    reveal
}

/// Writes the complete substring logic for the Circom circuit.
///
/// This function combines all substring-related logic into a single block.
///
/// # Arguments
///
/// * `idx` - The index of the current substring.
/// * `ranges` - A slice of tuples representing state transitions.
///
/// # Returns
///
/// A String containing the generated Circom code for the complete substring logic.
fn write_substr_logic(idx: usize, ranges: &[(usize, usize)]) -> String {
    let mut logic = String::new();
    logic += &format!("\tsignal prev_states{idx}[{}][msg_bytes];\n", ranges.len());
    logic += &format!("\tsignal is_substr{idx}[msg_bytes];\n");
    logic += &format!("\tsignal is_reveal{idx}[msg_bytes];\n");
    logic += &format!("\tsignal output reveal{idx}[msg_bytes];\n");
    logic += "\tfor (var i = 0; i < msg_bytes; i++) {\n";

    let sorted_ranges = sort_ranges(ranges);
    logic += &format!(
        "\t\t // the {idx}-th substring transitions: {:?}\n",
        sorted_ranges
    );

    logic += &write_prev_states(idx, &sorted_ranges);
    logic += &write_is_substr(idx, &sorted_ranges);
    logic += &write_is_reveal_and_reveal(idx);

    logic += "\t}\n";
    logic
}

/// Sorts the ranges of state transitions.
///
/// # Arguments
///
/// * `ranges` - A slice of tuples representing state transitions.
///
/// # Returns
///
/// A Vec of references to the sorted ranges.
fn sort_ranges(ranges: &[(usize, usize)]) -> Vec<&(usize, usize)> {
    let mut sorted = ranges.iter().collect::<Vec<_>>();
    sorted.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));
    sorted
}

/// Adds substring constraints to the Circom circuit.
///
/// This function generates the logic for substring matching and consecutive state tracking.
///
/// # Arguments
///
/// * `regex_dfa` - A reference to the RegexAndDFA struct containing the DFA and substring information.
///
/// # Returns
///
/// A Result containing the generated Circom code as a String, or a CompilerError.
fn add_substrs_constraints(regex_dfa: &RegexAndDFA) -> Result<String, CompilerError> {
    let accepted_state =
        get_accepted_state(&regex_dfa.dfa).ok_or(CompilerError::NoAcceptedState)?;
    let mut circom = String::new();

    circom += &write_consecutive_logic(accepted_state);

    circom += &format!(
        "\t// substrings calculated: {:?}\n",
        regex_dfa.substrings.substring_ranges
    );

    for (idx, ranges) in regex_dfa.substrings.substring_ranges.iter().enumerate() {
        circom += &write_substr_logic(idx, &ranges.iter().copied().collect::<Vec<_>>());
    }

    circom += "}";
    Ok(circom)
}

/// Generates a Circom template file for the given regex and DFA.
///
/// This function creates a Circom file containing the circuit logic for the regex matcher.
///
/// # Arguments
///
/// * `regex_and_dfa` - A reference to the RegexAndDFA struct containing the regex and DFA information.
/// * `circom_path` - The path where the generated Circom file should be saved.
/// * `template_name` - The name of the Circom template.
/// * `gen_substrs` - A boolean indicating whether to generate substring constraints.
///
/// # Returns
///
/// A Result indicating success or a CompilerError.
pub(crate) fn gen_circom_template(
    regex_and_dfa: &RegexAndDFA,
    circom_path: &Path,
    template_name: &str,
    gen_substrs: bool,
) -> Result<(), CompilerError> {
    let circom = gen_circom_allstr(
        &regex_and_dfa.dfa,
        template_name,
        &regex_and_dfa.regex_pattern,
        regex_and_dfa.has_end_anchor,
    );

    let mut file = File::create(circom_path)?;
    file.write_all(circom.as_bytes())?;

    if gen_substrs {
        let substrs = add_substrs_constraints(regex_and_dfa)?;
        file.write_all(substrs.as_bytes())?;
    }

    file.flush()?;
    Ok(())
}

/// Generates a Circom circuit as a string for the given regex and DFA.
///
/// This function creates a string containing the Circom circuit logic for the regex matcher.
///
/// # Arguments
///
/// * `regex_and_dfa` - A reference to the RegexAndDFA struct containing the regex and DFA information.
/// * `template_name` - The name of the Circom template.
///
/// # Returns
///
/// A Result containing the generated Circom code as a String, or a CompilerError.
pub(crate) fn gen_circom_string(
    regex_and_dfa: &RegexAndDFA,
    template_name: &str,
) -> Result<String, CompilerError> {
    let circom = gen_circom_allstr(
        &regex_and_dfa.dfa,
        template_name,
        &regex_and_dfa.regex_pattern,
        regex_and_dfa.has_end_anchor,
    );
    let substrs = add_substrs_constraints(regex_and_dfa)?;
    let result = circom + &substrs;
    Ok(result)
}
