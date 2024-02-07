use super::CompilerError;
use crate::get_accepted_state;
use crate::DFAGraph;
use crate::RegexAndDFA;
use std::collections::{HashMap, HashSet};

use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

fn gen_circom_allstr(dfa_graph: &DFAGraph, template_name: &str, regex_str: &str) -> String {
    let n = dfa_graph.states.len();
    let mut rev_graph = HashMap::<usize, HashMap<usize, Vec<u8>>>::new();
    let mut to_init_graph = vec![];
    let mut init_going_state: Option<usize> = None;

    for i in 0..n {
        rev_graph.insert(i, HashMap::new());
        to_init_graph.push(vec![]);
    }

    let mut accept_nodes = HashSet::<usize>::new();

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
    let mut multi_or_checks1 = HashMap::<String, usize>::new();
    let mut multi_or_checks2 = HashMap::<String, usize>::new();

    let mut lines = vec![];

    lines.push("\tfor (var i = 0; i < num_bytes; i++) {".to_string());
    lines.push(format!("\t\tstate_changed[i] = MultiOR({});", n - 1));

    for i in 1..n {
        let mut outputs = vec![];

        for (prev_i, k) in rev_graph.get(&(i as usize)).unwrap().iter() {
            let prev_i_num = *prev_i;
            let mut k = k.clone();
            k.sort();

            let mut eq_outputs = vec![];
            let mut vals = k.clone().into_iter().collect::<HashSet<u8>>();

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
                    multi_or_checks1.insert(eq_outputs_key, multi_or_i);
                    multi_or_i += 1;
                } else {
                    if let Some(multi_or_i) = multi_or_checks1.get(&eq_outputs_key) {
                        lines.push(format!(
                            "\t\tand[{}][i].b <== multi_or[{}][i].out;",
                            and_i, multi_or_i
                        ));
                    }
                }
            }

            outputs.push(and_i);
            and_i += 1;
        }

        if outputs.len() == 1 {
            lines.push(format!(
                "\t\tstates[i+1][{}] <== and[{}][i].out;",
                i, outputs[0]
            ));
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

                lines.push(format!(
                    "\t\tstates[i+1][{}] <== multi_or[{}][i].out;",
                    i, multi_or_i
                ));
                multi_or_checks2.insert(outputs_key, multi_or_i);
                multi_or_i += 1;
            } else {
                if let Some(multi_or_i_) = multi_or_checks2.get(&outputs_key) {
                    lines.push(format!(
                        "\t\tstates[i+1][{}] <== multi_or[{}][i].out;",
                        i, multi_or_i_
                    ));
                }
            }
        }

        lines.push(format!(
            "\t\tstate_changed[i].in[{}] <== states[i+1][{}];",
            i - 1,
            i
        ));
    }

    lines.push("\t\tstates[i+1][0] <== 1 - state_changed[i].out;".to_string());

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
    declarations.push("\tcomponent state_changed[num_bytes];\n".to_string());

    let mut init_code = vec![];
    init_code.push("\tstates[0][0] <== 1;".to_string());
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
        if gen_substrs {
            self.add_substrs_constraints(circom_path, circom)?;
        } else {
            let mut circom_file = File::create(circom_path)?;
            write!(circom_file, "{}", circom)?;
            circom_file.flush()?;
        }
        Ok(())
    }

    pub fn add_substrs_constraints(
        &self,
        circom_path: &PathBuf,
        mut circom: String,
    ) -> Result<(), CompilerError> {
        let accepted_state = get_accepted_state(&self.dfa_val).unwrap();
        circom += "\n";
        circom += "\tsignal is_consecutive[msg_bytes+1][2];\n";
        circom += "\tis_consecutive[msg_bytes][1] <== 1;\n";
        circom += "\tfor (var i = 0; i < msg_bytes; i++) {\n";
        circom += &format!("\t\tis_consecutive[msg_bytes-1-i][0] <== states[num_bytes-i][{}] * (1 - is_consecutive[msg_bytes-i][1]) + is_consecutive[msg_bytes-i][1];\n", accepted_state);
        circom += "\t\tis_consecutive[msg_bytes-1-i][1] <== state_changed[msg_bytes-i].out * is_consecutive[msg_bytes-1-i][0];\n";
        circom += "\t}\n";

        let substr_defs_array = &self.substrs_defs.substr_defs_array;
        circom += &format!(
            "\t// substrings calculated: {:?}\n",
            &self.substrs_defs.substr_defs_array
        );
        for (idx, defs) in substr_defs_array.into_iter().enumerate() {
            let num_defs = defs.len();
            circom += &format!("\tsignal is_substr{}[msg_bytes][{}];\n", idx, num_defs + 1);
            circom += &format!("\tsignal is_reveal{}[msg_bytes];\n", idx);
            circom += &format!("\tsignal output reveal{}[msg_bytes];\n", idx);
            circom += "\tfor (var i = 0; i < msg_bytes; i++) {\n";
            circom += &format!("\t\tis_substr{}[i][0] <== 0;\n", idx);
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
            for (j, (cur, next)) in defs.iter().enumerate() {
                circom += &format!(
                    "\t\tis_substr{}[i][{}] <== is_substr{}[i][{}] + ",
                    idx,
                    j + 1,
                    idx,
                    j
                );
                circom += &format!("states[i+1][{}] * states[i+2][{}];\n", cur, next);
                // if j != defs.len() - 1 {
                //     circom += " + ";
                // } else {
                //     circom += ";\n";
                // }
            }
            circom += &format!(
                "\t\tis_reveal{}[i] <== is_substr{}[i][{}] * is_consecutive[i][1];\n",
                idx, idx, num_defs
            );
            circom += &format!("\t\treveal{}[i] <== in[i+1] * is_reveal{}[i];\n", idx, idx);
            circom += "\t}\n";
        }
        circom += "}";
        let mut circom_file = File::create(circom_path)?;
        write!(circom_file, "{}", circom)?;
        circom_file.flush()?;
        Ok(())
    }
}
