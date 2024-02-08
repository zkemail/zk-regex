use crate::{DFAGraph, DFAState};
use regex::Regex;
use regex_automata::dfa::{dense::DFA, StartKind};
use std::collections::{BTreeSet, HashMap};

#[derive(Debug, Clone)]
struct DFAInfoState {
    typ: String,
    source: usize,
    edges: HashMap<String, usize>,
}

#[derive(Debug)]
struct DFAGraphInfo {
    states: Vec<DFAInfoState>,
}

fn parse_dfa_output(output: &str) -> DFAGraphInfo {
    let mut dfa_info = DFAGraphInfo { states: Vec::new() };

    let re = Regex::new(r"\*?(\d+): ((.+?) => (\d+),?)+").unwrap();
    for captures in re.captures_iter(output) {
        let src = captures[1].parse::<usize>().unwrap();
        let mut state = DFAInfoState {
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
            state.edges.insert(src, dst.parse::<usize>().unwrap());
        }
        dfa_info.states.push(state);
    }

    let mut eoi_pointing_states = BTreeSet::new();

    for state in &mut dfa_info.states {
        if let Some(eoi_target) = state.edges.get("EOI").cloned() {
            eoi_pointing_states.insert(eoi_target);
            state.typ = String::from("accept");
            state.edges.remove("EOI");
        }
    }

    let start_state_re = Regex::new(r"START-GROUP\(anchored\)[\s*\w*\=>]*Text => (\d+)").unwrap();
    let start_state = start_state_re.captures_iter(output).next().unwrap()[1]
        .parse::<usize>()
        .unwrap();

    // Sort states by order of appearance and rename the sources
    let mut sorted_states = DFAGraphInfo { states: Vec::new() };
    let mut sorted_states_set = BTreeSet::new();
    let mut new_states = BTreeSet::new();
    new_states.insert(start_state);
    while !new_states.is_empty() {
        let mut next_states = BTreeSet::new();
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
        // Check if the next_states are already in the sorted_states_set
        new_states.clear();
        for state in &next_states {
            if !sorted_states_set.contains(state) {
                new_states.insert(*state);
            }
        }
    }

    // Rename the sources
    let mut switch_states = HashMap::new();
    for (i, state) in sorted_states.states.iter_mut().enumerate() {
        let temp = state.source;
        state.source = i as usize;
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

fn dfa_to_graph(dfa_info: &DFAGraphInfo) -> DFAGraph {
    let mut graph = DFAGraph { states: Vec::new() };
    for state in &dfa_info.states {
        let mut edges = HashMap::new();
        let key_mappings: HashMap<&str, u8> = [
            ("\\n", 10),
            ("\\r", 13),
            ("\\t", 9),
            ("\\v", 11),
            ("\\f", 12),
            ("\\0", 0),
        ]
        .into();
        for (key, value) in &state.edges {
            let mut key: &str = key;
            if key == "' '" {
                key = " ";
            }
            let re = Regex::new(r"(.+)-(.+)").unwrap();
            if re.is_match(key) {
                let capture = re.captures_iter(key).next().unwrap();
                let mut start = &capture[1];
                let start_index;
                if start.starts_with("\\x") {
                    start = &start[2..];
                    start_index = u8::from_str_radix(start, 16).unwrap();
                } else {
                    if key_mappings.contains_key(start) {
                        start_index = *key_mappings.get(start).unwrap();
                    } else {
                        start_index = start.as_bytes()[0];
                    }
                }
                let mut end = &capture[2];
                let end_index;
                if end.starts_with("\\x") {
                    end = &end[2..];
                    end_index = u8::from_str_radix(end, 16).unwrap();
                } else {
                    if key_mappings.contains_key(end) {
                        end_index = *key_mappings.get(end).unwrap();
                    } else {
                        end_index = end.as_bytes()[0];
                    }
                }
                let char_range: Vec<u8> = (start_index..=end_index).collect();
                if edges.contains_key(value) {
                    let edge: &mut BTreeSet<u8> = edges.get_mut(value).unwrap();
                    for c in char_range {
                        edge.insert(c);
                    }
                } else {
                    edges.insert(*value, char_range.into_iter().collect());
                }
            } else {
                let index;
                if key.starts_with("\\x") {
                    key = &key[2..];
                    index = u8::from_str_radix(key, 16).unwrap();
                } else {
                    if key_mappings.contains_key(key) {
                        index = *key_mappings.get(key).unwrap();
                    } else {
                        index = key.as_bytes()[0];
                    }
                }
                if edges.contains_key(value) {
                    let edge: &mut BTreeSet<u8> = edges.get_mut(value).unwrap();
                    edge.insert(index);
                } else {
                    edges.insert(*value, vec![index].into_iter().collect());
                }
            }
        }

        graph.states.push(DFAState {
            r#type: state.typ.clone(),
            edges: edges,
            state: state.source,
        });
    }

    graph
}

pub fn regex_to_dfa(regex: &str) -> DFAGraph {
    let mut config = DFA::config().minimize(true);
    config = config.start_kind(StartKind::Anchored);
    config = config.byte_classes(false);
    config = config.accelerate(true);
    let re = DFA::builder()
        .configure(config)
        .build(&format!(r"^{}$", regex))
        .unwrap();
    let re_str = format!("{:?}", re);
    let graph = dfa_to_graph(&parse_dfa_output(&re_str));
    graph
}
