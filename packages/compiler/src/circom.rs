use itertools::Itertools;

use super::CompilerError;
use crate::get_accepted_state;
use crate::DFAGraph;
use crate::RegexAndDFA;
use std::collections::{BTreeMap, BTreeSet};

use std::fmt::format;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

fn gen_circom_allstr(dfa_graph: &DFAGraph, template_name: &str, regex_str: &str) -> String {
    let n = dfa_graph.states.len();
    let mut rev_graph = BTreeMap::<usize, BTreeMap<usize, Vec<u8>>>::new();
    let mut to_init_graph = vec![];
    let mut init_going_state: Option<usize> = None;

    for i in 0..n {
        rev_graph.insert(i, BTreeMap::new());
        to_init_graph.push(vec![]);
    }

    let mut accept_nodes = BTreeSet::<usize>::new();

    for i in 0..n {
        let node = &dfa_graph.states[i];
        for (k, v) in &node.edges {
            let chars: Vec<u8> = v.iter().cloned().collect();
            rev_graph.get_mut(k).unwrap().insert(i, chars.clone());

            if i == 0 {
                if let Some(index) = chars.iter().position(|&x| x == 94) {
                    init_going_state = Some(*k);
                    rev_graph.get_mut(&k).unwrap().get_mut(&i).unwrap()[index] = 255;
                }

                for j in rev_graph.get(&k).unwrap().get(&i).unwrap() {
                    if *j == 255 {
                        continue;
                    }
                    to_init_graph[*k].push(*j);
                }
            }
        }

        if node.r#type == "accept" {
            accept_nodes.insert(i);
        }
    }

    if let Some(init_going_state) = init_going_state {
        for (going_state, chars) in to_init_graph.iter().enumerate() {
            if chars.is_empty() {
                continue;
            }

            if rev_graph
                .get_mut(&(going_state as usize))
                .unwrap()
                .get_mut(&init_going_state)
                .is_none()
            {
                rev_graph
                    .get_mut(&(going_state as usize))
                    .unwrap()
                    .insert(init_going_state, vec![]);
            }

            rev_graph
                .get_mut(&(going_state as usize))
                .unwrap()
                .get_mut(&init_going_state)
                .unwrap()
                .extend_from_slice(chars);
        }
    }

    if accept_nodes.is_empty() {
        panic!("Accept node must exist");
    }

    let accept_nodes_array: Vec<usize> = accept_nodes.into_iter().collect();

    if accept_nodes_array.len() != 1 {
        panic!("The size of accept nodes must be one");
    }

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
    // let mut zero_starting_lines = vec![];

    lines.push("\tfor (var i = 0; i < num_bytes; i++) {".to_string());
    lines.push(format!("\t\tstate_changed[i] = MultiOR({});", n - 1));
    lines.push(format!("\t\tstates[i][0] <== 1;"));
    for i in 1..n {
        let mut outputs = vec![];
        zero_starting_and_idxes.insert(i, vec![]);
        // let mut state_change_lines = vec![];

        for (prev_i, k) in rev_graph.get(&(i as usize)).unwrap().iter() {
            let prev_i_num = *prev_i;
            if prev_i_num == 0 {
                zero_starting_states.push(i);
            }
            let mut k = k.clone();
            k.sort();

            let mut eq_outputs = vec![];
            let mut vals = k.clone().into_iter().collect::<BTreeSet<u8>>();

            if vals.is_empty() {
                continue;
            }

            let mut min_maxes = vec![];
            let mut cur_min = k[0];
            let mut cur_max = k[0];

            for idx in 1..k.len() {
                if cur_max == k[idx] {
                    continue;
                } else if cur_max + 1 == k[idx] {
                    cur_max += 1;
                } else {
                    if cur_max - cur_min >= 16 {
                        min_maxes.push((cur_min, cur_max));
                    }
                    cur_min = k[idx];
                    cur_max = k[idx];
                }
            }

            if cur_max - cur_min >= 16 {
                min_maxes.push((cur_min, cur_max));
            }

            for min_max in &min_maxes {
                for code in min_max.0..=min_max.1 {
                    vals.remove(&code);
                }
            }

            for min_max in &min_maxes {
                let min = min_max.0;
                let max = min_max.1;

                if range_checks[min as usize][max as usize].is_none() {
                    lines.push(format!("\t\tlt[{}][i] = LessEqThan(8);", lt_i));
                    lines.push(format!("\t\tlt[{}][i].in[0] <== {};", lt_i, min));
                    lines.push(format!("\t\tlt[{}][i].in[1] <== in[i];", lt_i));
                    lines.push(format!("\t\tlt[{}][i] = LessEqThan(8);", lt_i + 1));
                    lines.push(format!("\t\tlt[{}][i].in[0] <== in[i];", lt_i + 1));
                    lines.push(format!("\t\tlt[{}][i].in[1] <== {};", lt_i + 1, max));
                    lines.push(format!("\t\tand[{}][i] = AND();", and_i));
                    lines.push(format!("\t\tand[{}][i].a <== lt[{}][i].out;", and_i, lt_i));
                    lines.push(format!(
                        "\t\tand[{}][i].b <== lt[{}][i].out;",
                        and_i,
                        lt_i + 1
                    ));
                    eq_outputs.push(("and", and_i));
                    range_checks[min as usize][max as usize] = Some((lt_i, and_i));
                    lt_i += 2;
                    and_i += 1;
                } else {
                    if let Some((_, and_i)) = range_checks[min as usize][max as usize] {
                        eq_outputs.push(("and", and_i));
                    }
                }
            }

            for code in &vals {
                if eq_checks[*code as usize].is_none() {
                    lines.push(format!("\t\teq[{}][i] = IsEqual();", eq_i));
                    lines.push(format!("\t\teq[{}][i].in[0] <== in[i];", eq_i));
                    lines.push(format!("\t\teq[{}][i].in[1] <== {};", eq_i, code));
                    eq_outputs.push(("eq", eq_i));
                    eq_checks[*code as usize] = Some(eq_i);
                    eq_i += 1;
                } else {
                    if let Some(eq_i) = eq_checks[*code as usize] {
                        eq_outputs.push(("eq", eq_i));
                    }
                }
            }
            lines.push(format!("\t\tand[{}][i] = AND();", and_i));
            lines.push(format!(
                "\t\tand[{}][i].a <== states[i][{}];",
                and_i, prev_i_num
            ));

            if eq_outputs.len() == 1 {
                lines.push(format!(
                    "\t\tand[{}][i].b <== {}[{}][i].out;",
                    and_i, eq_outputs[0].0, eq_outputs[0].1
                ));
                if prev_i_num == 0 {
                    zero_starting_and_idxes.get_mut(&i).unwrap().push(and_i);
                }
            } else if eq_outputs.len() > 1 {
                let eq_outputs_key = serde_json::to_string(&eq_outputs).unwrap();

                if multi_or_checks1.get(&eq_outputs_key).is_none() {
                    lines.push(format!(
                        "\t\tmulti_or[{}][i] = MultiOR({});",
                        multi_or_i,
                        eq_outputs.len()
                    ));

                    for (output_i, (eq_type, eq_i)) in eq_outputs.iter().enumerate() {
                        lines.push(format!(
                            "\t\tmulti_or[{}][i].in[{}] <== {}[{}][i].out;",
                            multi_or_i, output_i, eq_type, eq_i
                        ));
                    }

                    lines.push(format!(
                        "\t\tand[{}][i].b <== multi_or[{}][i].out;",
                        and_i, multi_or_i
                    ));
                    if prev_i_num == 0 {
                        zero_starting_and_idxes.get_mut(&i).unwrap().push(and_i);
                    }
                    multi_or_checks1.insert(eq_outputs_key, multi_or_i);
                    multi_or_i += 1;
                } else {
                    if let Some(multi_or_i) = multi_or_checks1.get(&eq_outputs_key) {
                        lines.push(format!(
                            "\t\tand[{}][i].b <== multi_or[{}][i].out;",
                            and_i, multi_or_i
                        ));
                        if prev_i_num == 0 {
                            zero_starting_and_idxes.get_mut(&i).unwrap().push(and_i);
                        }
                    }
                }
            }
            if prev_i_num != 0 {
                outputs.push(and_i);
            }
            and_i += 1;
        }
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

            if multi_or_checks2.get(&outputs_key).is_none() {
                lines.push(format!(
                    "\t\tmulti_or[{}][i] = MultiOR({});",
                    multi_or_i,
                    outputs.len()
                ));

                for (output_i, and_i) in outputs.iter().enumerate() {
                    lines.push(format!(
                        "\t\tmulti_or[{}][i].in[{}] <== and[{}][i].out;",
                        multi_or_i, output_i, and_i
                    ));
                }
                if zero_starting_states.contains(&i) {
                    lines.push(format!(
                        "\t\tstates_tmp[i+1][{}] <== multi_or[{}][i].out;",
                        i, multi_or_i
                    ));
                } else {
                    lines.push(format!(
                        "\t\tstates[i+1][{}] <== multi_or[{}][i].out;",
                        i, multi_or_i
                    ));
                }
                multi_or_checks2.insert(outputs_key, multi_or_i);
                multi_or_i += 1;
            } else {
                if let Some(multi_or_i) = multi_or_checks2.get(&outputs_key) {
                    if zero_starting_states.contains(&i) {
                        lines.push(format!(
                            "\t\tstates_tmp[i+1][{}] <== multi_or[{}][i].out;",
                            i, multi_or_i
                        ));
                    } else {
                        lines.push(format!(
                            "\t\tstates[i+1][{}] <== multi_or[{}][i].out;",
                            i, multi_or_i
                        ));
                    }
                }
            }
        } else {
            if zero_starting_states.contains(&i) {
                lines.push(format!("\t\tstates_tmp[i+1][{}] <== 0;", i));
            } else {
                lines.push(format!("\t\tstates[i+1][{}] <== 0;", i));
            }
        }

        // if zero_starting_states.contains(&i) {
        //     zero_starting_lines.append(&mut state_change_lines);
        // } else {
        //     lines.append(&mut state_change_lines);
        // }
    }
    // let not_zero_starting_states = (1..n)
    //     .filter(|i| !zero_starting_states.contains(&i))
    //     .collect_vec();
    lines.push(format!(
        "\t\tfrom_zero_enabled[i] <== MultiNOR({})([{}]);",
        n - 1,
        (1..n)
            .map(|i| if zero_starting_states.contains(&i) {
                format!("states_tmp[i+1][{}]", i)
            } else {
                format!("states[i+1][{}]", i)
            })
            .collect::<Vec<_>>()
            .join(", ")
    ));
    for (i, vec) in zero_starting_and_idxes.iter() {
        if vec.len() == 0 {
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
    for i in 1..n {
        lines.push(format!(
            "\t\tstate_changed[i].in[{}] <== states[i+1][{}];",
            i - 1,
            i
        ));
    }

    // lines.push("\t\tstates[i+1][0] <== 1 - state_changed[i].out;".to_string());

    let mut declarations = vec![];
    declarations.push("pragma circom 2.1.5;\n".to_string());
    declarations
        .push("include \"@zk-email/zk-regex-circom/circuits/regex_helpers.circom\";\n".to_string());
    declarations.push(format!(
        "// regex: {}",
        regex_str.replace("\n", "\\n").replace("\r", "\\r"),
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

    declarations.push(format!("\tsignal states[num_bytes+1][{}];", n));
    declarations.push(format!("\tsignal states_tmp[num_bytes+1][{}];", n));
    declarations.push(format!("\tsignal from_zero_enabled[num_bytes+1];"));
    declarations.push(format!("\tfrom_zero_enabled[num_bytes] <== 0;"));
    declarations.push("\tcomponent state_changed[num_bytes];\n".to_string());

    let mut init_code = vec![];
    // init_code.push("\tstates[0][0] <== 1;".to_string());
    init_code.push(format!("\tfor (var i = 1; i < {}; i++) {{", n));
    init_code.push("\t\tstates[0][i] <== 0;".to_string());
    init_code.push("\t}\n".to_string());

    let mut final_code = declarations
        .into_iter()
        .chain(init_code)
        .chain(lines)
        .collect::<Vec<String>>();
    final_code.push("\t}".to_string());

    let accept_node = accept_nodes_array[0];
    let mut accept_lines = vec![];

    accept_lines.push("".to_string());
    accept_lines.push("\tcomponent final_state_result = MultiOR(num_bytes+1);".to_string());
    accept_lines.push("\tfor (var i = 0; i <= num_bytes; i++) {".to_string());
    accept_lines.push(format!(
        "\t\tfinal_state_result.in[i] <== states[i][{}];",
        accept_node
    ));
    accept_lines.push("\t}".to_string());
    accept_lines.push("\tout <== final_state_result.out;".to_string());

    final_code.extend(accept_lines);

    final_code.join("\n")
}

impl RegexAndDFA {
    pub fn gen_circom(
        &self,
        circom_path: &PathBuf,
        template_name: &str,
        gen_substrs: bool,
    ) -> Result<(), CompilerError> {
        let circom = gen_circom_allstr(&self.dfa_val, template_name, &self.regex_str);
        let mut circom_file = File::create(circom_path)?;
        write!(circom_file, "{}", circom)?;
        if gen_substrs {
            let substrs = self.add_substrs_constraints()?;
            write!(circom_file, "{}", substrs)?;
        }
        circom_file.flush()?;
        Ok(())
    }

    pub fn gen_circom_str(&self, template_name: &str) -> Result<String, CompilerError> {
        let circom = gen_circom_allstr(&self.dfa_val, template_name, &self.regex_str);
        let substrs = self.add_substrs_constraints()?;
        let result = circom + &substrs;
        Ok(result)
    }

    pub fn add_substrs_constraints(&self) -> Result<String, CompilerError> {
        let accepted_state = get_accepted_state(&self.dfa_val).unwrap();
        let mut circom: String = "".to_string();
        circom += "\n";
        circom += "\tsignal is_consecutive[msg_bytes+1][3];\n";
        circom += "\tis_consecutive[msg_bytes][2] <== 1;\n";
        circom += "\tfor (var i = 0; i < msg_bytes; i++) {\n";
        circom += &format!("\t\tis_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][{}] * (1 - is_consecutive[msg_bytes-i][2]) + is_consecutive[msg_bytes-i][2];\n", accepted_state);
        circom += "\t\tis_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];\n";
        circom += &format!("\t\tis_consecutive[msg_bytes-1-i][2] <== ORAnd()([(1 - from_zero_enabled[msg_bytes-i+1]), states[num_bytes-i][{}], is_consecutive[msg_bytes-1-i][1]]);\n", accepted_state);
        circom += "\t}\n";

        let substr_defs_array = &self.substrs_defs.substr_defs_array;
        circom += &format!(
            "\t// substrings calculated: {:?}\n",
            &self.substrs_defs.substr_defs_array
        );
        for (idx, defs) in substr_defs_array.into_iter().enumerate() {
            let num_defs = defs.len();
            circom += &format!("\tsignal is_substr{}[msg_bytes];\n", idx);
            circom += &format!("\tsignal is_reveal{}[msg_bytes];\n", idx);
            circom += &format!("\tsignal output reveal{}[msg_bytes];\n", idx);
            circom += "\tfor (var i = 0; i < msg_bytes; i++) {\n";
            // circom += &format!("\t\tis_substr{}[i][0] <== 0;\n", idx);
            let mut defs = defs.iter().collect::<Vec<&(usize, usize)>>();
            defs.sort_by(|a, b| {
                let start_cmp = a.0.cmp(&b.0);
                let end_cmp = a.1.cmp(&b.1);
                if start_cmp == std::cmp::Ordering::Equal {
                    end_cmp
                } else {
                    start_cmp
                }
            });
            circom += &format!("\t\t // the {}-th substring transitions: {:?}\n", idx, defs);
            circom += &format!(
                "\t\tis_substr{}[i] <== MultiOR({})([{}]);\n",
                idx,
                num_defs,
                defs.iter()
                    .map(|(cur, next)| format!("states[i+1][{}] * states[i+2][{}]", cur, next))
                    .collect::<Vec<_>>()
                    .join(", ")
            );
            // for (j, (cur, next)) in defs.iter().enumerate() {
            //     circom += &format!(
            //         "\t\tis_substr{}[i][{}] <== is_substr{}[i][{}] + ",
            //         idx,
            //         j + 1,
            //         idx,
            //         j
            //     );
            //     circom += &format!("states[i+1][{}] * states[i+2][{}];\n", cur, next);
            //     // if j != defs.len() - 1 {
            //     //     circom += " + ";
            //     // } else {
            //     //     circom += ";\n";
            //     // }
            // }
            circom += &format!(
                "\t\tis_reveal{}[i] <== is_substr{}[i] * is_consecutive[i][2];\n",
                idx, idx
            );
            circom += &format!("\t\treveal{}[i] <== in[i+1] * is_reveal{}[i];\n", idx, idx);
            circom += "\t}\n";
        }
        circom += "}";
        Ok(circom)
    }
}
