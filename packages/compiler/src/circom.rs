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

fn add_state_update(
    lines: &mut Vec<String>,
    i: usize,
    outputs: Vec<usize>,
    zero_starting_states: &mut Vec<usize>,
    multi_or_checks2: &mut BTreeMap<String, usize>,
    multi_or_i: &mut usize,
) {
    if outputs.len() == 1 {
        if zero_starting_states.contains(&i) {
            lines.push(format!(
                "\t\tstates_tmp[i+1][{}] <== and[{}][i].out;",
                i, outputs[0]
            ));
        } else {
            lines.push(format!(
                "\t\tstates[i+1][{}] <== and[{}][i].out;",
                i, outputs[0]
            ));
        }
    } else if outputs.len() > 1 {
        let outputs_key = serde_json::to_string(&outputs).unwrap();
        if let Some(&multi_or_index) = multi_or_checks2.get(&outputs_key) {
            if zero_starting_states.contains(&i) {
                lines.push(format!(
                    "\t\tstates_tmp[i+1][{}] <== multi_or[{}][i].out;",
                    i, multi_or_index
                ));
            } else {
                lines.push(format!(
                    "\t\tstates[i+1][{}] <== multi_or[{}][i].out;",
                    i, multi_or_index
                ));
            }
        } else {
            lines.push(format!(
                "\t\tmulti_or[{}][i] = MultiOR({});",
                *multi_or_i,
                outputs.len()
            ));
            for (output_i, and_i) in outputs.iter().enumerate() {
                lines.push(format!(
                    "\t\tmulti_or[{}][i].in[{}] <== and[{}][i].out;",
                    *multi_or_i, output_i, and_i
                ));
            }
            if zero_starting_states.contains(&i) {
                lines.push(format!(
                    "\t\tstates_tmp[i+1][{}] <== multi_or[{}][i].out;",
                    i, *multi_or_i
                ));
            } else {
                lines.push(format!(
                    "\t\tstates[i+1][{}] <== multi_or[{}][i].out;",
                    i, *multi_or_i
                ));
            }
            multi_or_checks2.insert(outputs_key, *multi_or_i);
            *multi_or_i += 1;
        }
    } else {
        if zero_starting_states.contains(&i) {
            lines.push(format!("\t\tstates_tmp[i+1][{}] <== 0;", i));
        } else {
            lines.push(format!("\t\tstates[i+1][{}] <== 0;", i));
        }
    }
}

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

fn add_state_changed_updates(lines: &mut Vec<String>, state_len: usize) {
    for i in 1..state_len {
        lines.push(format!(
            "\t\tstate_changed[i].in[{}] <== states[i+1][{}];",
            i - 1,
            i
        ));
    }
}

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
    let mut declarations = vec![];

    declarations.push("pragma circom 2.1.5;\n".to_string());
    declarations
        .push("include \"@zk-email/zk-regex-circom/circuits/regex_helpers.circom\";\n".to_string());

    declarations.push(format!(
        "// regex: {}",
        regex_str.replace("\n", "\\n").replace("\r", "\\r")
    ));

    declarations.push(format!("template {}(msg_bytes) {{", template_name));
    declarations.push("\tsignal input msg[msg_bytes];".to_string());
    declarations.push("\tsignal output out;\n".to_string());

    declarations.push("\tvar num_bytes = msg_bytes+1;".to_string());
    declarations.push("\tsignal in[num_bytes];".to_string());
    declarations.push("\tin[0]<==255;".to_string());
    declarations.push("\tfor (var i = 0; i < msg_bytes; i++) {".to_string());
    declarations.push("\t\tin[i+1] <== msg[i];".to_string());
    declarations.push("\t}\n".to_string());

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

    declarations.push(format!("\tsignal states[num_bytes+1][{}];", state_len));
    declarations.push(format!("\tsignal states_tmp[num_bytes+1][{}];", state_len));
    declarations.push("\tsignal from_zero_enabled[num_bytes+1];".to_string());
    declarations.push("\tfrom_zero_enabled[num_bytes] <== 0;".to_string());
    declarations.push("\tcomponent state_changed[num_bytes];\n".to_string());

    if end_anchor {
        declarations.push("\tsignal padding_start[num_bytes+1];".to_string());
        declarations.push("\tpadding_start[0] <== 0;".to_string());
    }

    declarations
}

fn generate_init_code(state_len: usize) -> Vec<String> {
    let mut init_code = vec![];

    // Initialize all states except the first one to 0
    init_code.push(format!("\tfor (var i = 1; i < {}; i++) {{", state_len));
    init_code.push("\t\tstates[0][i] <== 0;".to_string());
    init_code.push("\t}".to_string());

    // Add a blank line for readability
    init_code.push("".to_string());

    init_code
}

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

fn write_is_reveal_and_reveal(idx: usize) -> String {
    let mut reveal = String::new();
    reveal += &format!(
        "\t\tis_reveal{idx}[i] <== MultiAND(3)([out, is_substr{idx}[i], is_consecutive[i][2]]);\n"
    );
    reveal += &format!("\t\treveal{idx}[i] <== in[i+1] * is_reveal{idx}[i];\n");
    reveal
}

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

fn sort_ranges(ranges: &[(usize, usize)]) -> Vec<&(usize, usize)> {
    let mut sorted = ranges.iter().collect::<Vec<_>>();
    sorted.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));
    sorted
}

pub fn add_substrs_constraints(regex_dfa: &RegexAndDFA) -> Result<String, CompilerError> {
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
