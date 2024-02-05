use regex::Regex;
use regex_automata::dfa::{dense::DFA, StartKind};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone)]
struct State {
    typ: String,
    source: u32,
    edges: HashMap<String, u32>,
}

#[derive(Debug)]
struct DFAInfo {
    states: Vec<State>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GraphNode {
    #[serde(default)]
    r#type: String,
    edges: HashMap<String, u32>,
}

fn parse_dfa_output(output: &str) -> DFAInfo {
    let mut dfa_info = DFAInfo { states: Vec::new() };

    let re = Regex::new(r"\*?(\d+): ((.+?) => (\d+),?)+").unwrap();
    for captures in re.captures_iter(output) {
        let src = captures[1].parse::<u32>().unwrap();
        let mut state = State {
            source: src,
            typ: String::new(),
            edges: HashMap::new(),
        };
        if &captures[0][0..1] == "*" {
            state.typ = String::from("accept");
        }
        for transition in Regex::new(r"\s+[^=]+\s*=>\s*(\d+)+\s*|\s+=+\s*=>\s*(\d+)+")
            .unwrap()
            .captures_iter(&captures[0].to_string())
        {
            let trimmed_transition = transition[0].trim();
            let transition_vec = trimmed_transition.split("=>").collect::<Vec<&str>>();
            let mut transition_vec_iter = transition_vec.iter();
            let mut src = transition_vec_iter.next().unwrap().trim().to_string();
            if src.len() > 2 && src.chars().nth(2).unwrap() == '\\' {
                src = format!("{}{}", &src[0..2], &src[3..]);
            }
            let dst = transition_vec_iter.next().unwrap().trim();
            state.edges.insert(src, dst.parse::<u32>().unwrap());
        }
        dfa_info.states.push(state);
    }

    let mut eoi_pointing_states = HashSet::new();

    for state in &mut dfa_info.states {
        if let Some(eoi_target) = state.edges.get("EOI").cloned() {
            eoi_pointing_states.insert(eoi_target);
            state.typ = String::from("accept");
            state.edges.remove("EOI");
        }
    }

    let start_state_re = Regex::new(r"START-GROUP\(anchored\)[\s*\w*\=>]*Text => (\d+)").unwrap();
    let start_state = start_state_re.captures_iter(output).next().unwrap()[1]
        .parse::<u32>()
        .unwrap();

    // Sort states by order of appearance and rename the sources
    let mut sorted_states = DFAInfo { states: Vec::new() };
    let mut sorted_states_set = HashSet::new();
    let mut new_states = HashSet::new();
    new_states.insert(start_state);
    while !new_states.is_empty() {
        let mut next_states = HashSet::new();
        for state in &new_states {
            if let Some(state) = dfa_info.states.iter().find(|s| s.source == *state) {
                sorted_states.states.push((*state).clone());
                sorted_states_set.insert(state.source);
                for (_, dst) in &state.edges {
                    if !sorted_states_set.contains(dst) {
                        next_states.insert(*dst);
                    }
                }
            }
        }
        new_states = next_states;
    }

    // Rename the sources
    let mut switch_states = HashMap::new();
    for (i, state) in sorted_states.states.iter_mut().enumerate() {
        let temp = state.source;
        state.source = i as u32;
        switch_states.insert(temp, state.source);
    }

    // Iterate over all edges of all states
    for state in &mut sorted_states.states {
        for (_, dst) in &mut state.edges {
            *dst = switch_states.get(dst).unwrap().clone();
        }
    }

    sorted_states
}

fn dfa_to_graph(dfa_info: &DFAInfo) -> String {
    let mut graph = Vec::new();
    for state in &dfa_info.states {
        let mut edges = HashMap::new();
        let mut edges_to_node = HashMap::new();
        for (key, value) in &state.edges {
            let re = Regex::new(r"(.+)-(.+)").unwrap();
            if re.is_match(key) {
                let capture = re.captures_iter(key).next().unwrap();
                let start = capture[1].parse::<char>().unwrap();
                let end = capture[2].parse::<char>().unwrap();
                let char_range: Vec<String> = (start..=end)
                    .map(|c| format!("\"{}\"", c as u8 as char))
                    .collect();
                if edges_to_node.contains_key(value) {
                    let edges_to_node_vec: &mut Vec<String> = edges_to_node.get_mut(value).unwrap();
                    edges_to_node_vec.push(char_range.join(","));
                } else {
                    edges_to_node.insert(value, vec![char_range.join(",")]);
                }
            } else {
                if key == "' '" {
                    if edges_to_node.contains_key(value) {
                        let edges_to_node_vec: &mut Vec<String> =
                            edges_to_node.get_mut(value).unwrap();
                        edges_to_node_vec.push("\" \"".to_string());
                    } else {
                        edges_to_node.insert(value, vec!["\" \"".to_string()]);
                    }
                    continue;
                }
                if edges_to_node.contains_key(value) {
                    let edges_to_node_vec: &mut Vec<String> = edges_to_node.get_mut(value).unwrap();
                    edges_to_node_vec.push(format!("\"{}\"", key));
                } else {
                    edges_to_node.insert(value, vec![format!("\"{}\"", key)]);
                }
            }
        }
        // Copy edges_to_node to edges
        for (value, chars) in edges_to_node {
            let result = format!("[{}]", chars.join(","));
            edges.insert(result, *value);
        }
        graph.push(GraphNode {
            r#type: state.typ.clone(),
            edges: edges,
        });
    }

    let json_string = serde_json::to_string_pretty(&graph).unwrap();
    json_string
}

pub fn regex_to_dfa(regex: &str) -> Vec<Value> {
    let mut config = DFA::config().minimize(true);
    config = config.start_kind(StartKind::Anchored);
    config = config.byte_classes(false);
    config = config.accelerate(true);
    let re: DFA<Vec<u32>> = DFA::builder()
        .configure(config)
        .build(&format!(r"^{}$", regex))
        .unwrap();
    let re_str = format!("{:?}", re);
    let json = dfa_to_graph(&parse_dfa_output(&re_str));
    serde_json::from_str(&json).unwrap()
}
